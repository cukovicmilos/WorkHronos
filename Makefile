.PHONY: build run app test clean

build:
	swift build

run:
	swift run WorkHronos

app:
	scripts/make_app.sh

test:
	swift run workhronos-tests

clean:
	rm -rf .build dist
