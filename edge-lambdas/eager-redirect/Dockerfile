FROM public.ecr.aws/lambda/nodejs:16

# Updating dependencies may fix potential security vulnerabilities
RUN yum update -y

# The lambda task root is where the source code should go
WORKDIR $LAMBDA_TASK_ROOT

COPY package*.json ./
RUN npm ci --omit=dev

COPY src ./

ENV NODE_ENV='production'
CMD [ "index.handler" ]
