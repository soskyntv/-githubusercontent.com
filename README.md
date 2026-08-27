# -githubusercontent.com
!! Внимание, этот способ сгенерирован ИИ !! Я сам не знаю, но у меня работает данный способ так что используйте

# Как починить блокировку gist / raw.githubusercontent.com (GitHub) без VPN и без правки скриптов

## В чём проблема

С **27.08.2026** у многих провайдеров (особенно в РФ) перестали открываться:
- `gist.githubusercontent.com` (сырые файлы gist, которые качают скрипты)
- иногда `raw.githubusercontent.com`, `avatars.githubusercontent.com`, GitHub Pages

**Симптомы:**
- В браузере: `ERR_CONNECTION_TIMED_OUT`
- В скрипте/терминале: `Connection timed out`, зависание
- `ping` до `185.199.108.133` / `185.199.109.133` / `185.199.110.133` / `185.199.111.133` — **не проходит (100% потеря)**

**Причина:** провайдер блокирует **IPv4-подсеть Fastly** `185.199.108.0/22`, на которой живут эти домены. Это блокировка **на уровне IP/подсети**, а не по имени (SNI). Поэтому:

- ⚠️ **zapret / byedpi / GoodbyeDPI НЕ ПОМОГАЕТ** (это DPI-обходы по SNI — они бессильны, если пакеты до IP вообще не доходят). Это официально подтверждено в issue [StressOzz/Zapret-Manager#1023](https://github.com/StressOzz/Zapret-Manager/issues/1023).
- ✅ **VPN помогает** (трафик идёт через другую сеть).
- ✅ **Часто помогает хитрый обход через IPv6** — описано ниже.

---

## Ключевая идея: использовать рабочий IPv6

При блокировке IPv4-подсети `185.199.x`, у большинства провайдеров **IPv6 работает нормально**. Тот же CDN (Fastly) отдаёт контент по IPv6.

- `raw.githubusercontent.com` и `avatars.githubusercontent.com` **имеют собственные IPv6 (AAAA) записи** → у вас они, скорее всего, и так работают.
- А вот `gist.githubusercontent.com` **не имеет AAAA-записи** (только IPv4, который заблокирован) → поэтому именно gist не открывается.

**Решение: принудительно назначить gist рабочие IPv6-адреса Fastly через файл `hosts`.** URL в скриптах менять не нужно.

> Как проверить, что именно у вас блок по IP, а не общий: сравните доступность `raw.githubusercontent.com` и `gist.githubusercontent.com`:

```
Test-NetConnection raw.githubusercontent.com -Port 443
Test-NetConnection gist.githubusercontent.com -Port 443
```

Проверка по IPv4-IP напрямую (без имени) — должны все «падать»:
```
Test-NetConnection 185.199.108.133 -Port 443
```

---

## Шаг 1. Добавить IPv6-записи в hosts

Рабочие IPv6-адреса Fastly (проверены, отдают контент по SNI `gist.githubusercontent.com` и др.):

```
2606:50c0:8000::154 gist.githubusercontent.com
2606:50c0:8001::154 gist.githubusercontent.com
2606:50c0:8002::154 gist.githubusercontent.com
2606:50c0:8003::154 gist.githubusercontent.com
2606:50c0:8000::154 raw.githubusercontent.com
2606:50c0:8001::154 raw.githubusercontent.com
2606:50c0:8002::154 raw.githubusercontent.com
2606:50c0:8003::154 raw.githubusercontent.com
2606:50c0:8000::154 avatars.githubusercontent.com
2606:50c0:8001::154 avatars.githubusercontent.com
2606:50c0:8002::154 avatars.githubusercontent.com
2606:50c0:8003::154 avatars.githubusercontent.com
```

### Автоматически (рекомендуется)

Запустите от **имени администратора**:
```
C:\Users\Admin\Documents\zapret\fix-github-gist-ipv6.bat
```
(ПКМ → «Запуск от имени администратора»). Скрипт:
1. Закрывает зависшие процессы, блокирующие `hosts`.
2. Добавляет IPv6-записи.
3. Очищает DNS-кэш.

### Вручную

1. Откройте от администратора Блокнот и файл `C:\Windows\System32\drivers\etc\hosts`.
2. Вставьте строки выше в конец.
3. Сохраните.

### Без прав администратора (PowerShell/opencode)

Если вы работаете из терминала, которому не хватает прав, перезапустите терминал от имени администратора. Без прав записать в `C:\Windows\System32\drivers\etc\hosts` нельзя.

---

## Шаг 2. Очистить DNS-кэш

```
ipconfig /flushdns
```

---

## Шаг 3. Проверить

Убедитесь, что домен теперь резолвится на IPv6:
```
nslookup gist.githubusercontent.com
```
Должны появиться адреса `2606:50c0:...` (а не заблокированные `185.199.x`).

Проверьте загрузку файла (например, вашим скриптом или браузером). Пример на Python:
```python
import urllib.request
data = urllib.request.urlopen("https://gist.githubusercontent.com/USER/GISTID/raw/SHA/file").read()
print("OK", len(data))
```

---

## Что делать, если не помогло

1. **IPv6 может быть отключён/не работать.** Проверьте наличие глобального IPv6 и маршрута:
   ```
   ipconfig | findstr "IPv6"
   route print | findstr "::/0"
   ```
   Если IPv6 нет — способ не сработает, тогда только VPN.

2. **Ping/IPv6 до Fastly блокируется тоже.** Редко, но бывает. Тогда единственный вариант — VPN/прокси (см. ниже).

3. **Антивирус блокирует запись в hosts.** Если после запуска ошибки «файл используется другим процессом» — закройте зависшие окна/процессы, которые держат hosts (см. ниже), и повторите.

---

## Дополнительно: как найти процесс, который "держит" hosts

Иногда какая-то программа (или зависший скрипт) держит `hosts` в монопольном доступе, из-за чего его нельзя изменить. Найти и закрыть его:

```
handle64.exe -accepteula hosts
```
(утилита Sysinternals, официальная) — покажет `powershell.exe pid:XXXX  ... \drivers\etc\hosts`, затем:
```
taskkill /PID XXXX /F
```

---

## Резюме / что важно знать

- **zapret и аналог — не помогает** против этой блокировки (это блок IP-подсети, не SNI).
- **hosts + IPv6 — бесплатно, без VPN, без правки скриптов** — работает, потому что Fastly отдаёт те же данные по IPv6, а IPv4 у провайдера заблокирован.
- Если у вас нет IPv6 или блокируют и его — **только VPN** (загнать домены `gist.githubusercontent.com`, `raw.githubusercontent.com`, `avatars.githubusercontent.com` в VPN/маршрут, как советуют в issue).

Ссылка на обсуждение: [StressOzz/Zapret-Manager#1023](https://github.com/StressOzz/Zapret-Manager/issues/1023)

