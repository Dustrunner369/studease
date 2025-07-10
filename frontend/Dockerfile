# First build Angular app
FROM node:22 AS builder
WORKDIR /app
COPY package.json .
COPY package-lock.json .
RUN npm install
COPY ./ ./
RUN npm run build

# Then serve it with Nginx
FROM nginx:alpine
# Since we're using Angular Universal (SSR), it outputs to the 'browser' file.
COPY --from=builder /app/dist/study-spot-app/browser /usr/share/nginx/html 
COPY ./nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
