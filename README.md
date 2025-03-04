# Docker Challenge

## **Setup**

### **Objective:**
Deploy **HAProxy** to load balance traffic to three backends over **HTTPS** with a production **SSL certificate** for the sample domain: `purelogics.pltouchbase.com`.

### **Components:**
- **HAProxy (lb)** on ports **80** and **443**.
- **NGINX** backends on ports **8081, 8082, 8083**.
- **rsyslog** for logging on port **514**.
- **SSL certificates** managed by **Certbot**.

---

## **Issues Identified & Fixes**

### **1. Incorrect Network Configuration in `docker-compose.yml`**
**Issue:** `wrongNet` was incorrectly set up in `docker-compose.yml`.
**Fix:** Updated `docker-compose.yml` to define the correct network name and referenced it properly in the services.

### **2. Access Denied for `alyant-lorem-ipsum` Repository**
**Issue:** Image pulling error: `denied: requested access to the resource is denied`.
**Fix:**
- Ensured the correct repository is used.
- If it's a private registry, added `docker login` credentials.

### **3. Incorrect `STAGING=true` in HAProxy Environment Variables**
**Issue:** The `STAGING=true` flag was causing issues with **Let's Encrypt** certificate issuance.
**Fix:** select `STAGING=false` from HAProxy’s environment settings to ensure production certificates are issued.

### **4. BusyBox Image Version Not Found**
**Issue:** `busybox:1.21.21` is an invalid image and caused a build failure.
**Fix:** Replaced `busybox:1.21.21` with a valid image, e.g., `debian:buster-slim`.

### **5. HAProxy Installation Was Commented Out in Dockerfile**
**Issue:** HAProxy was not installed due to commented-out installation steps.
**Fix:** Uncommented and properly installed HAProxy in the Dockerfile.

### **6. File Permission Errors (`/bootstrap.sh`, `/certs.sh`, `/cert-renewal-haproxy.sh`)**
**Issue:** Scripts inside the container had incorrect permissions.
**Fix:** Updated permissions in `Dockerfile`:
```sh
RUN chmod +x /bootstrap.sh /certs.sh /cert-renewal-haproxy.sh
```

### **7. Crontab Not Loading in Dockerfile**
**Issue:** The crontab setup was failing inside the container.
**Fix:**
- Ensured the cron service is properly installed and running.
- Verified `crontab.txt` is copied correctly and formatted properly.
- Used `RUN echo "" >> /var/crontab.txt && crontab /var/crontab.txt ` to ensure the correct user is assigned.

### **8. HAProxy PID Ownership Issue (`Cannot create pidfile /run/haproxy.pid`)**
**Issue:** HAProxy failed to create its PID file due to incorrect ownership.
**Fix:**
- Added the correct permissions in Dockerfile:
```sh
RUN mkdir -p /run/haproxy && chown haproxy:haproxy /run/haproxy
```

### **9. Incorrect `EXPOSE` Configuration in Dockerfile**
**Issue:** The Dockerfile contained `EXPOSE 8080 8443` instead of the correct frontend LB ports.
**Fix:** Updated to expose the correct ports:
```sh
EXPOSE 80 443
```

### **10. `haproxy.cfg` Located in the Wrong Directory**
**Issue:** `haproxy.cfg` was in the root directory instead of `/conf`, causing HAProxy to fail.
**Fix:** Moved `haproxy.cfg` to `/conf/` and updated HAProxy’s startup command to reference the correct path.

### **11. Incorrect Script Path and Crontab Timing for Certificate Renewal**
**Issue:** The script path for cert renewal was incorrect, and the crontab timing was set improperly.
**Fix:**
- Corrected the path in the crontab file.
- Set a valid schedule to renew certificates every Sunday at 01:01 AM:
```sh
01 01 * * 7 /cert-renewal-haproxy.sh >> /var/log/cert-renewal.log 2>&1
```

### **12. Incorrect File Name for HAProxy Certificate (`haproxy.pem`)**
**Issue:** The certificate file was not correctly combined, leading to HAProxy not loading it properly.
**Fix:**
- Ensured the correct order of concatenation for HAProxy’s PEM file:
```sh
cat /etc/letsencrypt/live/domain/privkey.pem \
    /etc/letsencrypt/live/domain/fullchain.pem \
    > /etc/haproxy/certs/haproxy.pem
```
- Verified HAProxy is pointing to the correct PEM file.

---

- All fixes have been implemented and tested.
- The **HAProxy container** now loads certificates correctly and distributes traffic to the **NGINX backends**.
- **Logging** via `rsyslog` is working as expected.
- **Certbot** successfully renews SSL certificates and reloads HAProxy to apply them.


✅ **System is now production-ready!** 🚀







