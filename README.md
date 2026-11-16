# Лабораторна робота №3. Serverless API: API Gateway + Lambda + S3 (Terraform)

## Архітектура

```
Клієнт ──GET /books──▶ API Gateway (REST, stage "dev")
                           │  AWS_PROXY
                           ▼
                      Lambda (python3.12) ──GetObject──▶ S3: kimachuk-books-data/books.json
```

Уся інфраструктура описана в Terraform (`terraform/`) і розгортається в **floci**,
локальному емуляторі AWS у Docker. Той самий код працює і з AWS Free Tier: потрібно
лише виставити `use_floci = false`.

| Файл | Вміст |
|---|---|
| `providers.tf` | провайдер AWS з ендпоінтами floci (`http://localhost:4566`) |
| `variables.tf` | регіон, назва проєкту, stage, перемикач floci/AWS |
| `main.tf` | S3 bucket + об'єкт, IAM-роль, Lambda, API Gateway (resource, method, integration, deployment, stage) |
| `outputs.tf` | `api_url`, ID API, назви bucket і Lambda |
| `lambda/handler.py` | код Lambda |
| `data/books.json` | дані, що завантажуються в S3 |

## Деплой

```bash
cd lab3
docker compose up -d            # запуск floci
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
terraform output api_url
```
📸 Вивід `terraform apply` (`Apply complete!`) і `terraform output`.

## Перевірка

```bash
URL=$(terraform output -raw api_url)
curl -s "$URL" | python3 -m json.tool
curl -s "$URL?author=Франко" | python3 -m json.tool
```
📸 Відповідь API (у терміналі або в браузері).

Посилання на API має вигляд:
```
http://localhost:4566/restapis/<api_id>/dev/_user_request_/books
```
(для справжнього AWS це `https://<api_id>.execute-api.us-east-1.amazonaws.com/dev/books`)

> Якщо Lambda повертає помилку доступу до S3 (контейнер Lambda не бачить `host.docker.internal`),
> поміняйте `S3_ENDPOINT` у `main.tf` на адресу контейнера floci, наприклад `http://floci:4566`,
> і повторіть `terraform apply`.

Видалення: `terraform destroy -auto-approve && docker compose down`.

---

## Опис API

**Base URL:** значення `terraform output api_url` без `/books`

### `GET /books`
Повертає список книжок, що зберігаються в S3 (`books.json`).

**Query-параметри (необов'язкові):**
| Параметр | Тип | Опис |
|---|---|---|
| `author` | string | фільтр за автором (пошук підрядка без урахування регістру) |

**Відповідь `200 OK`:**
```json
{
  "count": 1,
  "items": [
    {"id": 4, "title": "Захар Беркут", "author": "Іван Франко", "year": 1883}
  ]
}
```

**Відповідь `500`:** `{"error": "<опис помилки читання з S3>"}`

**Приклад:**
```bash
curl "http://localhost:4566/restapis/<api_id>/dev/_user_request_/books?author=Леся"
```
