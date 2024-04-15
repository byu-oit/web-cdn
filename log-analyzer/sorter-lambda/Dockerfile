FROM public.ecr.aws/lambda/nodejs:16

# Updating dependencies may fix potential security vulnerabilities
RUN yum update -y

# The lambda task root is where the source code should go
WORKDIR $LAMBDA_TASK_ROOT

COPY . ./
RUN npm ci

RUN npm run build

ENV NODE_ENV='production'
CMD [ "lib/lambda.handler" ]
