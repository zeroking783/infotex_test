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
