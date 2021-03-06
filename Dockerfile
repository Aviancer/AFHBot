FROM ruby:3
COPY ./app /app
WORKDIR /app
RUN bundle install
CMD ["/app/run.sh"]
