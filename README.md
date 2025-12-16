# Yocto_Linux_Reboot_service

# Install：互動式安裝(Inactive installation, need to input testing cycles and reboot times
./install-simple-boot-test.sh
# 會詢問測試次數和延遲時間


# 安裝後命令(Command can used after installation)
boot-status      # 查看狀態
boot-stop        # 停止測試
boot-start       # 開始測試
boot-reset       # 重置計數
boot-config      # 查看配置

# 修改配置(Change cycles and reboottimes)
nano /etc/boot-test.conf
# 修改後重啟服務(Restart service)
systemctl daemon-reload
systemctl enable boot-test
systemctl start boot-test
systemctl restart boot-test

# restart testing
boot-reset
systemctl restart boot-test
