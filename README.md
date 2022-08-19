# yt-live-cast

## 概要

深夜のゲリラ配信対策として、YouTubeチャンネルの配信開始を検知してGoogle Cast対応デバイスにキャストするためのシェルスクリプトです。

検知できるのは公開での配信のみで、限定公開やメンバー限定の配信、プレミア公開は検知できません。

## 動作環境

UNIX/Linux互換で、[curl](https://curl.se/)と[catt](https://github.com/skorokithakis/catt)が動作する環境であればほぼ動作すると思います。
動作確認はFreeBSD/amd64 13.1、Windows 11 64bitのWSL2上のDebian 11、Android 13上のTermuxで行っています。

HTMLの取得のために[curl](https://curl.se/)を、キャストと音量の設定のために[catt](https://github.com/skorokithakis/catt)を使用しますので、実行可能な状態にしておいてください。

キャスト先デバイスにはYouTubeのキャストに対応したものを使用してください。
Nest Hub、Chromecast、Android TVあたりが使用できると思います。
動作確認はNest Hubで行っています。

Google HomeやChromecast AudioのようなオーディオのみのデバイスはYouTubeのキャストに対応していないため使用できません。

## 設定

スクリプト冒頭のキャスト先IPアドレスと音量を環境に合わせて変更してください。

    # キャスト先デバイスのIPアドレス
    ipaddr=192.168.1.86
    
    # 音量
    volume=100

cattコマンドにパスが通っていない場合はパスを指定してください。

    # cattコマンド
    catt=$HOME/.local/bin/catt

## 使い方

    % sh yt-live-cast.sh <チャンネルID>

## 例

    % sh yt-live-cast.sh UCay6Y3oEoiC6ZEE2G0UZu_A

## ライセンス

本スクリプトはMITライセンスとします。
詳細については[LICENSE](LICENSE)を参照してください。
