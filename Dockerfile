FROM ruby:3
COPY ./app /app
WORKDIR /app
RUN bundle install

ENV SERVICE_NAME="afhbot"
RUN addgroup --gid 1001 --system $SERVICE_NAME && \
    adduser --system --ingroup $SERVICE_NAME --shell /bin/false --disabled-password --uid 1001 $SERVICE_NAME
USER $SERVICE_NAME

CMD ["/app/run.sh"]
