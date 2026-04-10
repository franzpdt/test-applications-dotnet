# test-applications-dotnet

A self-hosted .NET 10 REST API for managing tasks, with stress-test endpoints and Swagger UI.

## Configuration

The following environment variables control runtime behaviour:

| Variable | Default | Description |
|---|---|---|
| `APP_PORT` | `5000` | Port Kestrel listens on |
| `APP_LOG_PATH` | `./logs` | Directory for daily rolling log files |

Logs are written to both **stdout** and a rolling file (`<APP_LOG_PATH>/taskapi-YYYYMMDD.log`).

---

## API Endpoints

### Tasks

The database is seeded with 5 tasks on startup. All data is held in memory and lost on restart.

| Method | Route | Description |
|---|---|---|
| `GET` | `/api/tasks` | List all tasks |
| `GET` | `/api/tasks/{id}` | Get a task by ID |
| `POST` | `/api/tasks` | Create a new task |
| `PUT` | `/api/tasks/{id}` | Update an existing task |
| `DELETE` | `/api/tasks/{id}` | Delete a task |

**Task schema:**
```json
{
  "id": 1,
  "title": "Buy groceries",
  "description": "Milk, eggs, bread",
  "isCompleted": false,
  "createdAt": "2026-04-10T15:30:40Z"
}
```

### Stress

| Method | Route | Query param | Default | Description |
|---|---|---|---|---|
| `GET` | `/api/stress/cpu` | `seconds` | `10` | Busy-loops on one CPU core for the given duration |
| `GET` | `/api/stress/memory` | `seconds` | `10` | Allocates 10 MB every 500 ms for the given duration |

Both endpoints accept `seconds` between 1 and 300 and return a JSON summary when done.

### Swagger UI

The interactive API documentation is served at the root URL: `http://localhost:<APP_PORT>/`

---

## Deployment

### Local — bash script

```bash
# Default port 5000, logs in ./logs
./start.sh

# Override via env vars
APP_PORT=8080 APP_LOG_PATH=/var/log/taskapi ./start.sh
```

### Local — dotnet CLI

```bash
APP_PORT=5000 APP_LOG_PATH=./logs dotnet run --project TaskApi
```

### Docker

```bash
# Build
docker build -t task-api:latest .

# Run
docker run -p 5000:5000 \
  -e APP_PORT=5000 \
  -e APP_LOG_PATH=/app/logs \
  task-api:latest
```

### Kubernetes

```bash
# Push image to your registry and update the image field in deployment.yaml, then:
kubectl apply -f deployment.yaml
```

The manifest in `deployment.yaml` creates:
- A **Deployment** with 1 replica, readiness/liveness probes and an `emptyDir` volume for logs
- A **ClusterIP Service** exposing port 80 → container port 5000

To expose the API externally, change the `Service` type to `LoadBalancer` or add an `Ingress` resource.
