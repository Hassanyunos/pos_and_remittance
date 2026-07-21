# POS & Remittance

Flutter application organized by feature:

```
lib/
  app/
  core/database/
  features/
    auth/
    home/
    user_management/
```

On first launch, the database seeds one administrator account:

- Email: `admin@example.com`
- Password: `admin123`

There is no public registration screen. After signing in, an administrator can
create staff or additional administrator accounts from **Create user**.
