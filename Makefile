all:
	docker pull ruby:3
	docker build . -t afhbot
