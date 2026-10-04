# The backend's generated API (rulebook-to-node-postgres-api output).
# deploy.sh builds this with the API folder as the build context.
FROM node:20-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev
COPY . .
ENV PORT=42441
EXPOSE 42441
CMD ["node", "index.js"]
