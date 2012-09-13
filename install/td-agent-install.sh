#!/bin/sh

# td-agent,plugin が依存するパッケージをインストール
yum -y install httpd.x86_64 libxml2-devel.x86_64 libxslt-devel.x86_64 gcc make

# td-agent のリポジトリを登録
cat <<'EOF' > /etc/yum.repos.d/td.repo
[treasuredata]
name=TreasureData
baseurl=http://packages.treasure-data.com/redhat/$basearch
gpgcheck=0
enabled=0
EOF

# td-agentをインストール
yum --enablerepo=treasuredata -y install td-agent

# apacheのログにtd-agentからアクセスできるよう権限を調整
chgrp td-agent /var/log/httpd/
chmod g+rx /var/log/httpd/

# td-agentの設定
cp /etc/td-agent/td-agent.conf /etc/td-agent/td-agent.conf.bk

cat <<_EOF_ 1>/etc/td-agent/td-agent.conf
####
## Output descriptions:
##

## match tag=debug.** and dump to console
<match debug.**>
 type stdout
</match>


## File input
## read apache logs continuously and tags td.apache.access
<source>
  type tail
  format apache
  path /var/log/httpd/access_log
  tag apache.access
</source>

<match apache.access>
   type s3

   aws_key_id [ここにaccess keyを入力]
   aws_sec_key [ここにsecret keyを入力]
   s3_bucket [ここにバケット名を入力]
   s3_endpoint s3-ap-northeast-1.amazonaws.com

# バケットの下記パスに保存されます。
   path logs/
   buffer_path /var/log/td-agent/buffer/s3

   time_slice_format %Y%m%d-%H
#   time_slice_wait 10m
   flush_interval 5s
   utc
</match>
_EOF_

#nokogiri対応
/usr/lib64/fluent/ruby/bin/gem install nokogiri -- --with-xml2-lib=/usr/lib64 --with-xml2-include=/usr/include/libxml2/ --with-xslt-dir=/usr/include/libxslt

# apacheを起動
service httpd start

echo "==== インストール完了"
echo "/etc/td-agent/td-agent.conf にアクセスキー/バケット名を設定後、td-agentを起動してください。"
