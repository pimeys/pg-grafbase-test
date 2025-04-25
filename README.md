# How

```bash
docker compose up -d
psql postgresql://postgres:grafbase@localhost:5432/postgres -f test-database.sql
export GRAFBASE_ACCESS_TOKEN="asdf"
grafbase dev
```
