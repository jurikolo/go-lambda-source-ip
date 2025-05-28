build-source-ip:
	cd source-ip && go build -v && cd ..
run-source-ip:
	cd source-ip && go run . || cd ..
