$pcEpoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$state = Invoke-RestMethod -Uri "http://192.168.0.106/api/v1/state" -Method Get
$diff = $state.epoch - $pcEpoch
Write-Output "PC UTC Unix : $pcEpoch"
Write-Output "ESP Epoch   : $($state.epoch)"
Write-Output "ESP Synced  : $($state.timeSynced)"
Write-Output "Clock Drift : $diff seconds"
Write-Output "Channels    : $($state.channels | ConvertTo-Json -Compress)"
