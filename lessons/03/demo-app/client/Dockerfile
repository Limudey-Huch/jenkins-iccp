FROM nginx:1.27-alpine

COPY index.html style.css app.js /usr/share/nginx/html/
COPY nginx.conf.template /etc/nginx/templates/default.conf.template

# SERVER_ADDR (e.g. "server-dev.jewelry.local:5000") is injected at container
# start via an ECS task definition environment variable. The base nginx image
# runs envsubst on every file in /etc/nginx/templates/ automatically before
# starting nginx, so no custom entrypoint script is needed here.

EXPOSE 80
