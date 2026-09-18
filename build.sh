#!/bin/sh

if [ -z "$1" ]; then
    echo "Ошибка: не указан исходный файл"
    echo "Использование: $0 <файл>"
    exit 1 # не указан файл в команде
fi

SOURCE="$1"

echo "Попытка сборки файла: $SOURCE"

if [ ! -f "$SOURCE" ]; then
    echo "Ошибка: файл '$SOURCE' не найден"
    exit 2 # файл не найден в аудитории
fi

echo "Анализ файла: $SOURCE"

OUTPUT=$(grep -i "^[[:space:]]*\(//\|/\*\|%\|#\)[[:space:]]*Output:" "$SOURCE" | head -1 | sed 's|.*Output:[[:space:]]*||')

if [ -z "$OUTPUT" ]; then
    echo "Ошибка: не найден комментарий 'Output:' в файле '$SOURCE'"
    echo "Добавьте комментарий: Output: имя_файла"
    exit 3 # не найден комментарий output
fi

echo "Найдено имя выходного файла: $OUTPUT"

WORK_DIR=$(mktemp -d)

if [ ! -d "$WORK_DIR" ]; then
    echo "Ошибка: не удалось создать временный каталог"
    exit 4 # что-то с созданием временной дирректории
fi

trap 'rm -rf "$WORK_DIR"' EXIT INT TERM HUP

echo "Создан временный каталог: $WORK_DIR"

SOURCE_DIR=$(cd "$(dirname "$SOURCE")" && pwd)
SOURCE_NAME=$(basename "$SOURCE")

echo "Исходный файл находится в: $SOURCE_DIR"

cp "$SOURCE" "$WORK_DIR/"

cd "$WORK_DIR" || exit 4 # что-то с созданием временной дирректории

EXTENSION=$(echo "$SOURCE_NAME" | sed 's|.*\.||')

echo "Определено расширение: .$EXTENSION"

case "$EXTENSION" in
    c)
        echo "Компиляция C-программы..."
        cc -o "$OUTPUT" "$SOURCE_NAME" 2> build.log
        BUILD_RESULT=$?
        ;;
    cpp|cxx|cc)
        echo "Компиляция C++ программы..."
        c++ -o "$OUTPUT" "$SOURCE_NAME" 2> build.log
        BUILD_RESULT=$?
        ;;
    tex)
        echo "Компиляция TeX-документа..."
        pdflatex -interaction=nonstopmode -jobname="$OUTPUT" "$SOURCE_NAME" > build.log 2>&1
        BUILD_RESULT=$?
        case "$OUTPUT" in
            *.pdf) ;;
            *) OUTPUT="$OUTPUT.pdf" ;;
        esac
        ;;
    *)
        echo "Ошибка: неизвестный тип файла '.$EXTENSION'"
        echo "Поддерживаются: .c, .cpp, .cxx, .cc, .tex"
        exit 5 # неизвестный тип файла
        ;;
esac

if [ "$BUILD_RESULT" -ne 0 ]; then
    echo "Ошибка: компиляция завершилась с кодом $BUILD_RESULT"
    echo "--- Лог сборки ---"
    cat build.log
    echo "------------------"
    exit 6 # ошибка скомпилирования
fi

if [ ! -f "$OUTPUT" ]; then
    echo "Ошибка: компилятор не создал выходной файл '$OUTPUT'"
    exit 7 # выходной файл не создан
fi

cp "$OUTPUT" "$SOURCE_DIR/"

echo "Успешно! Файл '$OUTPUT' создан рядом с исходным файлом: $SOURCE_DIR/$OUTPUT"