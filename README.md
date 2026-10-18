# 林毅玮的个人网站

网站源码位于 `personal-website/`，是无需构建的 HTML / CSS / JavaScript 静态网站。
GitHub 个人主页：https://github.com/lywcoder

## 本地预览

在仓库根目录执行：

```powershell
python -m http.server 8000 --bind 127.0.0.1 --directory personal-website
```

打开 http://127.0.0.1:8000 。修改静态文件后刷新即可。

## 内容定位与后续建设

目前定位为“山东大学计算机专业本科生的学习与实践主页”，关注机器学习、数据挖掘、聚类算法和推荐系统。
介绍依据 2026 年 10 月提供的简历；年级变化后需同步修改页面，不推测入学与毕业年份。

1. **先积累可核验的作品。** 为每个真实项目补上问题、本人工作、方法、结果和仓库链接。学习项目也值得展示，不必写没有依据的项目数量、熟练度或工作年限。
2. **先写两三篇有内容的文章。** 可从阿里云部署记录、机器学习课程练习复盘或聚类算法实验入手。这些是选题建议，尚未作为已完成项目或已发布文章展示。
3. **项目说明要有证据。** 算法实验记录数据集、运行方式、评价指标和局限；部署文章记录架构、遇到的问题与解决方式，配图时遮挡账号和服务器敏感信息。
4. **博客规模增长后再引入静态生成。** 当前手写页面足够。文章多起来时，可评估用 Markdown 管理文章并生成静态页面，避免过早加入数据库、登录和后台管理。
5. **有正式域名后完善搜索展示。** 增加 canonical、分享预览图、robots.txt 和 sitemap.xml，并统一根域名与 www 的访问入口。当前未填写猜测的域名。
6. **优化图片。** 现有头像约 480 KB、图标约 641 KB；后续生成适合头像展示尺寸的 WebP/AVIF 和小尺寸 favicon，以减少首次加载流量。

## 公开信息的选择

- 展示学校、专业、技术基础、研究兴趣及 GitHub。
- 暂不发布手机号、原始简历，也不公开包含手机号的简历邮箱；未核实的旧邮箱与占位社交账号已移除。当前公开入口为 GitHub 个人主页，它不是消息发送服务。
- 如果需要直接联系，补充一个你确认用于公开展示的邮箱，再添加 mailto 链接。
- 若要提供简历下载，先制作专门的公开版本。成绩、排名和英语成绩可按科研申请或求职的目标选择加入，并注明时间与评分口径。
- 联系表单原先只会延时显示“发送成功”，没有实际投递功能，已移除。以后确实需要表单时再接服务端与邮件投递，并在服务端处理校验、限流与错误反馈。

## 阿里云部署建议

以下方案根据当前纯静态页面提出，未连接或变更你的云账号。部署前先确认已有产品、所在地域、域名与备案进度。

### 已有 ECS 或轻量应用服务器：优先复用

推荐链路：域名 → 云解析 DNS → 服务器 Nginx → 静态文件。
当前站点不需要 Node.js 常驻进程、数据库或容器集群。

1. 根据服务器实际系统安装 Nginx，确认服务运行。
2. 将 `personal-website/` **里面的文件**上传到独立站点目录，例如 `/var/www/lywcoder`。不要把整个仓库、.git、临时文件、云密钥或原始简历放到 Web 根目录。
3. 在 Nginx 的 `http` 上下文内增加独立站点配置。下面是局部示例，域名和路径必须替换；它不是完整的 HTTPS 上线配置：

```nginx
server {
    listen 80;
    server_name example.com www.example.com;
    root /var/www/lywcoder;
    index index.html;

    charset utf-8;
    autoindex off;
    add_header X-Content-Type-Options nosniff always;

    location / {
        try_files $uri $uri/ =404;
    }

    error_page 404 /404.html;
    location = /404.html {
        internal;
    }

    location ~ /\. {
        deny all;
    }
}
```

4. 在服务器上执行 `sudo nginx -t`，通过后再执行 `sudo systemctl reload nginx`。不要直接覆盖已有站点配置。
5. 为域名添加指向服务器公网 IPv4 的 A 记录；仅在确认服务器支持 IPv6 后添加 AAAA 记录。
6. 配置匹配域名的有效 HTTPS 证书和 443 监听，验证证书与页面资源正常后，将 HTTP 跳转到 HTTPS。设置证书到期提醒或自动续期。
7. 安全组与系统防火墙开放网站所需的 80/443；SSH 管理端口仅向你的管理地址开放，使用密钥登录。
8. 静态文件按版本留档，发布时保留上一个可用版本；先验证再切换，出现问题可回滚。后续再考虑用 GitHub Actions 自动部署。

### 尚无服务器、希望减少运维：评估 OSS 静态网站托管

推荐链路：自定义域名 → OSS 静态站点；有实际加速需求时再评估 CDN。
这是适用性建议，不代表 OSS 在所有流量下都更便宜，需要比较存储、请求与公网流量等费用。

1. 创建专用于网站公开文件的 Bucket，上传 `personal-website/` 中的文件。
2. 配置静态网站首页 `index.html`、错误页 `404.html`，错误响应保持 HTTP 404。
3. 选择适合的读取策略。直接从 OSS 公开访问需要允许匿名读取网站对象；不要把其他私人文件混入该 Bucket，也不要授予公开写入或列举权限。若使用私有源站与 CDN，按对应回源授权方案配置。
4. 绑定自己的域名并设置 CNAME，配置 HTTPS。OSS 默认域名访问 HTML 可能触发下载，不能把默认对象 URL 当作正式网站入口。
5. HTML 使用较短缓存或重新验证；CSS/JS 在使用长期缓存前先采用内容哈希或版本号。当前文件名固定，不应直接设置一年 immutable 缓存。
6. OSS 不运行服务端代码，留言、登录或邮件投递功能需要独立服务。

### 中国内地部署的备案顺序

若托管在中国内地，先按备案主体所在省市要求完成 ICP 备案，再对外提供网站服务。
阿里云个人网站备案文档还要求在网站开通后 30 日内办理公安联网备案。
取得真实备案号后再补充页脚和相应官方查询链接，不在页面放示例号码。
单独购买域名或 OSS 不等于已经具备首次备案所需的全部资源，先核对阿里云备案资格与支持的云产品。

## 上线检查

- 手机窄屏无横向溢出，菜单可打开、关闭和键盘操作。
- 深浅主题可切换；关闭本地存储后页面仍可使用。
- 所有链接有真实目标，无虚假文章、空链接和模拟成功的表单。
- HTTPS、首页、头像与静态资源正常；不存在的 URL 返回 HTTP 404。
- 发布目录仅含公开站点文件；原始简历和部署凭据留在站点目录之外。
- 设置费用预算和告警，定期检查账单；告警通常不等于自动停止计费。

## 官方参考

查阅日期：2026-10-18。

- [OSS 静态网站托管及跳转规则](https://help.aliyun.com/zh/oss/developer-reference/putbucketwebsite)
- [OSS 自定义域名与 HTTPS 访问说明](https://help.aliyun.com/zh/oss/how-to-access-oss-resources-through-https)
- [个人网站备案快速入门](https://help.aliyun.com/zh/icp-filing/basic-icp-service/getting-started/quick-start-for-icp-filing-for-personal-websites)
- [备案前服务器与接入信息检查](https://help.aliyun.com/zh/icp-filing/basic-icp-service/user-guide/icp-filing-server-access-information-check)



