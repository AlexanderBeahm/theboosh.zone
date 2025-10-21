# Build stage for frontend
FROM node:lts-alpine AS frontend-builder
WORKDIR /frontend
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build

# Final stage for Perl application
FROM perl:5.42
WORKDIR /usr/src/hello-perld

# Copy dependency file first for better layer caching
COPY Makefile.PL /usr/src/hello-perld/

# Install necessary Perl modules using cpanm
RUN cpanm --installdeps --notest .

# Copy application files
COPY . /usr/src/hello-perld

# Copy built frontend assets from builder stage
COPY --from=frontend-builder /frontend/dist /usr/src/hello-perld/lib/HelloPerld/Public/dist

# Copy and set up entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 3000
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["morbo", "./script/hello-perld"]
