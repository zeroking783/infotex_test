## 1. Архив
В этом шаге меня просто просят скачать архив в котором хранятся файлы для сборки `sqlite3.so`. Качаем его командой
```bash
wget https://www.sqlite.org/2018/sqlite-amalgamation-3260000.zip
```
Ну и конечно его надо распаковать командой
```bash
unzip sqlite-amalgamation-3260000.zip
```
## 2. Руководство
Пока не увидел там чего-то мега полезного. Ну окей, SQLite3 можно собрать самому. Но это используется для какого-то тюнинга, но мне не нужно никак тюнить. Тогда просто компилирую с базовыми настройками

## 3. CMakeLists.txt и компиляция
Поскольку не просят как-то тюнить SQLite3 на процессе компиляции, то используем просто базовые настройки в `CMakeLists.txt`. Это такой файл, в котором описывается как компилировать программу на C (как `Dockerfile` для контейнеров). Напишем его
```CMakeLists.txt
# Просто хороший тон указать версию, чтобы CMake не ругался
cmake_minimum_required(VERSION 3.10)

# Название проекта
project(SQLiteBuild)

# Указываем все исходные файлы, которые нужны для компиляции
file(GLOB SQLITE_SRC *.c)

# Создаем динамическую библиотеку .so (типа как подключаемая библиотека в Python)
add_library(sqlite3 SHARED ${SQLITE_SRC})

# Устанавливаем флаги компиляции
target_compile_options(sqlite3 PRIVATE -Wall -O2)

# Устанавливаем путь для библиотеки
install(TARGETS sqlite3 DESTINATION /usr/local/lib)
```
Здесь стоит сделать небольшое уточнение по поводу флагов `target_compile_options`:
- **PRIVATE** - при компиляции других программ, которые зависят от `sqlite3.so` не будут применяться флаги, которые использовались для компиляции `sqlite3.so`
- **-Wall** - это настройка за отвечает вывод логов компиляции, этот вариант выводит многие предупреждения при компиляции
- **-02** - уровень оптимизации во время компиляции, этот вариает является сбалонсированным, компиляция будет происходить с умеренной скоростью и программа будет эффективно работать

Перед запуском генерации `Makefile` стоит создать отедльную директорию `build`, чтобы все скомпилированное хранилось там
``` bash
mkdir build && cd build
```
Теперь генерируем `Makefile` с помощью `cmake`
``` bash
cmake ..
```
В процессе выполнения `cmake` будут выведены некоторые логи, но они дают не очень много информации. 
Теперь в папке `build` будут лежать файлы:
- **cmake_install.cmake** - нужен уже после компиляции, в нем описано как размещать программу на компьютере, чтобы все работало
- **CMakeCache.txt** - хранит хэш прошлой сборки, чтобы все собиралось быстрее при незначительныз изменениях
- **Makefile** - говорит `make` как нужно компилировать программу
- **CMakeFiles/** - различные настройки и временные файлы для CMake (юзлесс видимо)

Осталось по сгенерированному `Makefile` скомпилировать динамическую библиотеку `sqlite3.so`
```bash
make
```
Выведутся логи, там будут некоторые предупреждения, но я доверяю коду, в котором на каждую строчку написано более 600 строчек тестов.
Результатом всех описанных действий будет файл скомпилированной динамеческой библиотеки `sqlite3.so`.

## 4. Docker
Теперь нужно написать `Dockerfile`, в котором будет выполняться все вышеописанное. В ТЗ есть упомянание о легковесности образа, так что используем многослойную сборку
```Dockerfile
# Возьму alphine за базовый образ, потому что он самый легковесный
FROM alpine:3.14 as builder

# Скачиваю необходимые утилиты, не забываю очистить кэш для оптимизации
RUN apk add --no-cache \
	cmake \
	gcc \
	g++ \
	make \
	wget \
	unzip

# Скачиваем и распаковываем исходники SQLite
WORKDIR /sqlite3
RUN wget https://www.sqlite.org/2018/sqlite-amalgamation-3260000.zip \
	&& unzip sqlite-amalgamation-3260000.zip \
	&& rm -rf sqlite-amalgamation-3260000.zip

# Копируем CMakeLists.txt
COPY CMakeLists.txt /sqlite3/sqlite-amalgamation-3260000/CMakeLists.txt

# Компилируем SQLite, сохраняем логи в файл
RUN mkdir build \
	&& mkdir /var/log/sqlite3 \
	&& cd build \
	&& cmake /sqlite3/sqlite-amalgamation-3260000 \
	&& make > /var/log/sqlite3/compilation.log 2>&1 \
	&& rm -rf /sqlite3/sqlite-amalgamation-3260000

# Этап 2: Финальный образ
FROM alpine:3.14

# На всякий случай оставляю в финальном образе gcc, по тз нужно
RUN apk add --no-cache gcc

# Копируем скомпилированную библиотеку и логи из этапа сборки
RUN mkdir /var/log/sqlite3
COPY --from=builder /var/log/sqlite3/compilation.log /var/log/sqlite3/compilation.log
COPY --from=builder /sqlite3/build/libsqlite3.so /usr/lib/libsqlite3.so

# Устанавливаем рабочую директорию для контейнера
WORKDIR /sqlite3

# Заглушка для контейнера (если необходимо)
CMD ["/bin/sh"]
```
Билдим образ написанного
```bash
sudo docker build -t bakvivas/build-sqlite3 .
```
Запускам для проверки, на всякий случай
```bash
docker run -it bakvivas/build-sqlite3 /bin/sh
```
Убеждаемся, что библиотека есть в контейнере, логи записаны.
Также отправим образ в Docker Hub, это пригодится на шаге 7
```bash 
sudo docker push bakvivas/build-sqlite3
```

## 5. Подготовка виртуальной машины
Буду делать в Vagrant, потому что до этого уже тестировал в нем playbookи Ansible. Нужно написать Vagrantfile, который будет конфигурировать виртаульную машину
```Vagrantfile
Vagrant.configure("2") do |config|

	# Использую debian образ с Vagrant Box Catalog, как указано в ТЗ
	config.vm.box = "file:///home/bakvivas/vagrant_boxes/a7e0500d-dbff-11ef-b23b-1e508bf425ce"
	
	config.vm.define "sqlite3" do |test_server|
	
		# Делаю машину доступной в приватной сети, чтобы я мог на ней в будущем тестировать playbook
		test_server.vm.network "private_network", ip: "192.168.56.101"
	end
end
```
Я взял самый последний debian образ на Vagrant Box Catalog, из-за ограничений пришлось скачать.

## 6. Playbook для установки Docker
Я привык такие вещи выносить в отдельные роли, но делаю как в ТЗ. 
Не буду сюда переписывать playbook (install_docker.yaml) и inventory (inventory.ini), займут слишком много места и там ничего сложного нет. Запускаю playbook командой
``` bash
ansible-playbook install_docker.yaml -i inventory.ini --ask-become-pass
```
*root password*: **vagrant**

## 7. Выполнение пунктов 1-4 с помощью playbook
Как я понял, нужно просто сделать все действия из пунктов 1-4, но с помощью Ansible.
Все выполняет playbook (all_in_vagrant.yaml). Логи сохраняются в привычную директорию /var/log/sqlite3/compilation.log. Также к docker build на виртуальной машине добавил docker pull image.

## 8. Дополнительная часть
Теперь надо сделать пункты 1-4 с помощью gitlab-ci. Для этого нужно запустить свой gitlab runner. Я буду это делать с помощью docker
``` bash
docker pull gitlab/gitlab-runner:latest   

# Делаем сохранение конфигов и поддержку запуска контейнеров внутри контейнера
docker run -d --name gitlab-runner \
  --restart always \
  -v /srv/gitlab-runner/config:/etc/gitlab-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gitlab/gitlab-runner:latest

# Регистрируем gitlab runner
# Executor - docker
# Токен берется в самом gitlab
docker exec -it gitlab-runner gitlab-runner register

# Перезапускаем для принятия изменения
docker restart gitlab-runner
```
После этого новйы runner должен отобразиться в gitlab
