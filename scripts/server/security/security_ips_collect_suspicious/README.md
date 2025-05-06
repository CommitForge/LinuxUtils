
---

# Collect suspicious IPs

## `security_ips_collect_suspicious.sh`

This script analyzes Apache access logs to identify suspicious IP addresses responsible for HTTP 4xx and 5xx errors. It filters out safe IPs (whitelist) and those already blocked by the system firewall, then appends new, unique offenders to a persistent list for further review or action.

---

### ✅ Features

- Works on **Ubuntu/Debian** (UFW) and **RHEL/CentOS** (firewalld or iptables)
- Detects appropriate Apache log path based on OS
- Extracts IPs causing HTTP 4xx (client) and 5xx (server) errors
- Filters out:
  - Whitelisted IPs
  - IPs already blocked by the firewall
- Appends only new, unique IPs to a persistent list
- Uses secure temporary files and cleans up after execution

---

### 📂 File Paths

You can customize these paths directly in the script:

| Variable             | Default Path                                 | Description                                |
|----------------------|-----------------------------------------------|--------------------------------------------|
| `APACHE_LOG_PATH`    | `/var/log/apache2/access.log`                 | Apache log for Ubuntu/Debian               |
| `APACHE_LOG_PATH_RHEL` | `/var/log/httpd/access_log`                | Apache log for RHEL/CentOS                 |
| `IP_LIST_PATH`       | `/opt/security/error_ips.txt`                | Persistent list of suspicious IPs          |
| `WHITELIST_PATH`     | `/opt/security/whitelist.txt`                | List of trusted IPs to ignore              |

> **Note:** Ensure the `/opt/security/` directory exists:
```bash
sudo mkdir -p /opt/security
```

---

### 🔧 Setup

1. **Make the script executable:**
   ```bash
   chmod +x security_ips_collect_suspicious.sh
   ```

2. **Ensure Apache logs and firewall commands are accessible** (you may need to run as root).

3. *(Optional)* Create a whitelist file:
   ```bash
   sudo nano /opt/security/whitelist.txt
   ```

---

### 🚀 Usage

Run manually:
```bash
sudo ./security_ips_collect_suspicious.sh
```

Or schedule it with cron (e.g., every hour):
```bash
sudo crontab -e
```

Add:
```cron
0 * * * * /full/path/to/security_ips_collect_suspicious.sh
```

---

### 🔐 Firewall Compatibility

The script automatically detects and uses one of the following firewalls to identify already-blocked IPs:

- **UFW** (`ufw status`)
- **firewalld** (`firewall-cmd --list-blacklist`)
- **iptables** (`iptables -L INPUT`)

If no supported firewall is detected, it proceeds without filtering blocked IPs.

---

### 📦 Output

Newly identified IPs are saved (appended uniquely) to:
```
/opt/security/error_ips.txt
```

You can use this list to trigger alerts or automate blocking.

---

