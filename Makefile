build-source-ip:
	cd source-ip && go build -v -o bootstrap && cd ..
run-source-ip:
	cd source-ip && go run . || cd ..
