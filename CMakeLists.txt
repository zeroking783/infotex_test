cmake_minimum_required(VERSION 3.10)
project(SQLiteBuild)

# Указываем исходные файлы
file(GLOB SQLITE_SRC *.c)
# Для запуска через .gitlab-ci.yml
# file(GLOB SQLITE_SRC /builds/zeroking783/infotex_test/sqlite-amalgamation-3260000/*.c)

# Создаем динамическую библиотеку .so
add_library(sqlite3 SHARED ${SQLITE_SRC})

# Устанавливаем флаги компиляции
target_compile_options(sqlite3 PRIVATE -Wall -O2)

# Устанавливаем путь для библиотеки (опционально)
install(TARGETS sqlite3 DESTINATION /usr/local/lib)
