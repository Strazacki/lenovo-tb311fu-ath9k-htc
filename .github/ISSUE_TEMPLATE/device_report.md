---
name: Hardware / Runtime Test Report
about: Submit physical test results of ath9k_htc on your device
title: '[TEST REPORT] '
labels: test-report
assignees: ''
---

**Device Information**
- Device: Lenovo Tab TB311FU
- Build Number / Fingerprint:
- Kernel Version (`uname -a`):
- Root method & version:

**Test Checklist**
- [ ] USB Enumeration (0cf3:9271 detected)
- [ ] Firmware upload (htc_9271-1.4.0.fw loaded)
- [ ] HTC initialization (33 credits)
- [ ] Module loaded (`insmod ath9k_htc.ko` returned 0)
- [ ] External PHY visible in `iw phy` (e.g. `phy2`)
- [ ] Monitor mode activated (e.g. `wlan1` set to monitor)
- [ ] Raw packet capture tested (tcpdump / airodump-ng)
- [ ] Packet injection tested (aireplay-ng)

**Logs & Diagnostic Output**
Please attach or paste output from `scripts/collect-device-info.sh`.
