#!/bin/sh

# yt-live-cast.sh
#
# Copyright (c) 2022 SLT
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


# キャスト先デバイスのIPアドレス
ipaddr=192.168.1.86

# 音量
volume=100

# スリープ時間の範囲
sleep_min=5
sleep_max=60

# cattコマンドのパス
catt=$HOME/.local/bin/catt

# 詳細メッセージの出力
verbose=0

# シグナル受信時クリーンアップ処理
cleanup() {
  if [ -n "$child" ]
  then
    kill -TERM "$child"
  fi

  rm -f $tempfile

  exit 1
}

# 配信のHTMLを取得
fetchHTML()
{
  local url=$1
  local file=$2
  curl -s -o "$file" "$url"
}

# HTMLからステータスを取得
extractStatus()
{
  local file=$1

  if [ -e $file ]
  then
    cat $file | \
      grep -o '"playabilityStatus".*"status":"[^"]*"' | \
      grep -o '"status":"[^"]*"' | \
      sed -e 's/^"status":"//' -e 's/"$//'
  fi
}

# HTMLから正規化されたURLを取得
extractCanonical()
{
  local file=$1

  if [ -e $file ]
  then
    cat $file | \
      grep -o '<link rel="canonical" href="[^"]*"' | \
      sed -e 's/^.*href="//' -e 's/"$//'
  fi
}

# HTMLから開始時刻を取得
extractStartTime()
{
  local file=$1

  if [ -e $file ]
  then
    cat $file | \
      grep -o '"scheduledStartTime":"[^"]*"' | \
      sed -e 's/^"scheduledStartTime":"//' -e 's/"$//'
  fi
}

# デバイスにキャストして音量を設定
cast()
{
  local url=$1

  echo Cast $url to $ipaddr. 1>&2
  $catt -d $ipaddr cast "$url"

  echo Set volume to $volume. 1>&2
  $catt -d $ipaddr volume $volume
}

# キャストを停止
stopCast()
{
  echo Stop casting. 1>&2
  $catt -d $ipaddr stop
}

# スリープを実行
execSleep()
{
  sleeptime=$1

  if [ $verbose -ge 1 ]
  then
    echo Sleep $sleeptime seconds. 1>&2
  fi

  sleep $sleeptime &

  child=$!
  wait "$child"
  child=
}


if [ -z "$1" ]
then
  # チャンネルIDが指定されていないので使用法を出力して終了
  echo usage: $0 \<channel ID\> 1>&2
  exit 2
fi

# 変数の初期化

chid="$1"
liveurl="https://www.youtube.com/channel/$chid/live"

prevstatus=
prevurl=
casting=0
child=

tempfile=`mktemp`

# 配信のURLを出力
echo Live URL: $liveurl 1>&2

# 終了時に一時ファイルと子プロセスをクリーンアップするためシグナルをトラップ
trap cleanup HUP INT QUIT TERM

# メインループ
while true
do
  if [ $verbose -ge 1 ]
  then
    echo 1>&2
  fi

  # HTMLを取得
  fetchHTML "$liveurl" $tempfile

  if [ $? -ne 0 ]
  then
    # HTMLを取得できなかった
    echo Couldn\'t fetch HTML. 1>&2
    execSleep $sleep_max
    continue
  fi

  # HTMLから情報を取得
  status=`extractStatus $tempfile`
  url=`extractCanonical $tempfile`
  starttime=`extractStartTime $tempfile`

  # 一時ファイルを削除
  rm -f $tempfile

  if [ -z "$url" ]
  then
    # 正規化URLを取得できなかった
    echo Could\'t extract canonical URL from HTML. 1>&2
    execSleep $sleep_max
    continue
  fi

  # 情報を出力
  if [ $verbose -ge 1 ]
  then
    echo Status: $status 1>&2
    echo Canonical URL: $url 1>&2
    echo Start Time: $starttime 1>&2
  fi

  if [ \( \( "$url" != "$prevurl" \) -o \
    \( "$prevstatus" = "LIVE_STREAM_OFFLINE" \) -o \
    \( -z "$prevstatus" \) \) \
    -a \( "$status" = "OK" \) ]
  then
    # 配信の開始を検知したのでデバイスにキャスト
    cast "$url"
    casting=1
  fi

  if [ \( $casting -ne 0 \) -a \
    \( \( "$url" != "$prevurl" \) -a \
    \( \( "$status" = "LIVE_STREAM_OFFLINE" \) -o \( -z "$status" \) \) \) ]
  then
    # 配信の終了を検知したのでキャストを停止
    # 使用する場合はコメントアウトを外してください
    #stopCast
    casting=0
  fi

  prevstatus="$status"
  prevurl="$url"

  # 現在時刻を取得
  currenttime=`date +%s`

  if [ \( "$status" = "OK" \) -o \( -z "$starttime" \) ]
  then
    # 配信中、もしくは開始時刻を取得できなかった
    sleeptime=$sleep_max
  else
    # 開始時刻までの時間を計算してスリープ時間とする
    sleeptime=`expr $starttime - $currenttime`

    # スリープ時間の最大値・最小値処理
    if [ $sleeptime -gt $sleep_max ]
    then
      sleeptime=$sleep_max
    elif [ $sleeptime -lt $sleep_min ]
    then
      sleeptime=$sleep_min
    fi
  fi

  # スリープを実行
  execSleep $sleeptime
done
