FROM nginx:alpine

# Remove os arquivos padrão do Nginx para evitar conflitos
RUN rm -rf /usr/share/nginx/html/*

# Copia todo o conteúdo da pasta do seu projeto para o diretório público do Nginx
# Se os arquivos estiverem dentro da pasta vendas360:
COPY vendas360/ /usr/share/nginx/html/

# Expõe a porta padrão de internet
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
