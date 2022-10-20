# format all files in the project
format: dprint flutter-format

dprint:
	dprint fmt

# flutter lacks a dprint plugin, use its own formatter
flutter-format:
	flutter format . --fix

clean:
	flutter clean
	cd rust && cargo clean && cd -
