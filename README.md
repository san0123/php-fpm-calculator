### 동작 설명
> 시스템에 설치된 메모리 정보를 가지고 계산하여 적절한 php-fpm 설정 값을 도출해 냅니다.
>> 가용 메모리(FREE+BUFF) + php-fpm_사용중 - 전체메모리10%(버퍼/캐쉬) = php-fpm사용할 메모리

### 설치 및 사용
> ```bash
> ~]# cd /opt
> ~]# git clone https://github.com/san0123/php-fpm-calculator
> ~]# cd php-fpm-calculator
> ~]# bash php-fpm-calculator.sh 1
>
> ~]# bash php-fpm-calculator.sh 3
> ```

### 예제 결과 값. (메모리 2GB / 1개 pool)
> ```bash
> -----------------------------------------
>           TOTAL   USED    BUFF    FREE
> -----------------------------------------
> MEMORY    1709M   651M    740M    318M
> -----------------------------------------
> httpd used 141.4MB
> mariadbd used 386.6MB
> php-fpm used 160.8MB
> -----------------------------------------
> FreeMemory(0.3G) + Buffer(0.7G) + PHP_Consume(0.2G) - Memory_10%(0.2G) = 1.0G
> -----------------------------------------
> 37.36 MB php-fpm: pool www
> 37.23 MB php-fpm: pool www
> 35.23 MB php-fpm: pool www
> 18.88 MB php-fpm: master process (/etc/php-fpm.conf)
> php-fpm child average memory usage 36.6M
> -----------------------------------------
> 1 site use to 1047.7M memory per each.
> -----------------------------------------
> pm                              = dynamic
> pm.max_children                 = 28
> pm.start_servers                = 15
> pm.min_spare_servers            = 9
> pm.max_spare_servers            = 21
> pm.max_requests                 = 500
> -----------------------------------------
> ```
