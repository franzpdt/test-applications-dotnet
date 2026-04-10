# Build stage
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY TaskApi/TaskApi.csproj TaskApi/
RUN dotnet restore TaskApi/TaskApi.csproj

COPY TaskApi/ TaskApi/
RUN dotnet publish TaskApi/TaskApi.csproj -c Release -o /app/publish

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

COPY --from=build /app/publish .

ENV APP_PORT=5000
ENV APP_LOG_PATH=/app/logs

EXPOSE 5000

ENTRYPOINT ["dotnet", "TaskApi.dll"]
