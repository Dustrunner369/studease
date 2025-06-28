# First we build
FROM node:22 AS builder
WORKDIR /app
COPY package.json .
COPY package-lock.json .
RUN npm install
COPY ./ ./
RUN npm run build

# Then we serve it
FROM nginx:alpine
COPY --from=builder /app/dist/study-spot-app /usr/share/nginx/html
EXPOSE 80