FROM public.ecr.aws/docker/library/node:18-alpine

## Install python (for AWS CLI) and git
RUN apk --no-cache add python3 git

## Install AWS CLI
RUN apk --no-cache add aws-cli

ENV ASSEMBLER_HOME=/usr/src/assembler/

RUN mkdir -p /usr/src/assembler

WORKDIR /usr/src/assembler

ADD package.json yarn.lock ./

RUN yarn install --production \
    && yarn cache clean

ADD . ./

RUN chmod a+x bin/cdn-assembler.js && yarn link

RUN mkdir -p /usr/src/app

WORKDIR /usr/src/app

CMD ["/app/cdn-assembler", "--config", "main-config.yml"]
