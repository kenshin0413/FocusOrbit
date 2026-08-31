# FocusOrbit Announcement Manifest

AivisSpeechからはWAVで書き出してください。以下のファイル名をそのまま使用します。

| # | File name | Announcement |
|---:|---|---|
| 01 | `cabin_authorized.wav` | 認証が完了いたしました。まもなく、発射シーケンスを開始いたします。 |
| 02 | `cabin_prelaunch.wav` | 発射準備が整いました。シートに深く腰掛け、そのままお待ちください。 |
| 03 | `cabin_liftoff.wav` | メインエンジン点火。離床します。 |
| 04 | `cabin_orbit_inserted.wav` | 地球周回軌道への投入を確認しました。船内は通常航行へ移行します。 |
| 05 | `cabin_cruise.wav` | ご搭乗ありがとうございます。当船は自動航行へ移行しました。到着まで、どうぞ静かにお過ごしください。 |
| 06 | `cabin_midpoint.wav` | 航程の半分を通過しました。航行は順調です。 |
| 07 | `cabin_arrival.wav` | まもなく目的地へ到着いたします。到着シーケンスを開始します。 |
| 08 | `cabin_lunar_descent.wav` | 月面への最終降下を開始します。接地まで、そのままお待ちください。 |
| 09 | `cabin_mars_descent.wav` | 火星地表への最終降下を開始します。降下速度は正常です。 |
| 10 | `cabin_docking_approach.wav` | 宇宙ステーションとの最終ドッキングシーケンスを開始します。 |
| 11 | `cabin_orbit_approach.wav` | 目的地周回軌道への投入を開始します。 |
| 12 | `cabin_lunar_complete.wav` | 接地を確認しました。月面基地へ到着いたしました。 |
| 13 | `cabin_mars_complete.wav` | 接地を確認しました。火星へ到着いたしました。 |
| 14 | `cabin_station_complete.wav` | ドッキングが完了しました。宇宙ステーションへ到着いたしました。 |
| 15 | `cabin_orbit_complete.wav` | 軌道投入が完了しました。目的地へ到着いたしました。 |
| 16 | `cabin_pause.wav` | 航行を一時停止しました。準備ができましたら、再開してください。 |
| 17 | `cabin_resume.wav` | 自動航行を再開します。 |
| 18 | `cabin_interrupted.wav` | 航行を終了しました。現在までの記録を保存しました。 |

## Delivery

Place all WAV files in:

`/Users/kenshin/Desktop/FocusOrbit/VoiceExports`

The app integration step will convert them to AAC and map each file to its event.
