# Build stage
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY TaskApi/TaskApi.csproj TaskApi/
RUN dotnet restore TaskApi/TaskApi.csproj

COPY TaskApi/ TaskApi/
RUN dotnet publish TaskApi/TaskApi.csproj -c Debug -o /app/publish

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

RUN useradd --no-create-home --shell /bin/false appuser && \
    mkdir -p /app/logs && chown -R appuser:appuser /app

COPY --from=build --chown=appuser:appuser /app/publish .

USER appuser

ENV APP_PORT=5000
ENV APP_LOG_PATH=/app/logs

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:${APP_PORT}/api/tasks || exit 1

ENTRYPOINT ["dotnet", "TaskApi.dll"]
