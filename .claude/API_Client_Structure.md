
## Full Call Flow

```
View
 └─ controller.login(email, password)
      │
      ▼
Controller
 └─ AuthService.to.login(email, password)
      │
      ▼
AuthService                          ← owns session state & token storage
 └─ _repo.login(email, password)
      │
      ▼
AuthRepository                       ← owns endpoint path & fromJson
 └─ _client.post<UserModel>(
        '/auth/login',
        data: {...},
        fromJson: UserModel.fromJson,
    )
      │
      ▼
ApiClient + Dio                      ← owns HTTP, interceptors, error mapping
 └─ POST /auth/login
      │
      ├─ 200 → ApiResponse<UserModel>.data = UserModel
      │
      └─ 4xx/5xx/timeout → throws ApiException
```

---
