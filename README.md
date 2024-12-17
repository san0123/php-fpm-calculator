### 동작 설명
> 시스템에 설치된 메모리 정보를 가지고 계산하여 적절한 php-fpm 설정 값을 도출해 냅니다.
> 
>> 사용하는 CMS에 따라 child 의 메모리 사용량이 다를 수 있고 사이트가 성장함에 따라 php 에서 사용하는 메모리량이 늘어 날 수 있으므로
>> 주기적으로 계산을 해서 최적의 값을 맞추어 가는 개념으로 운용 하시기 바랍니다. 
> 
>> 가용 메모리(FREE+BUFF)
>>
>> \+ php-fpm 사용중 사용중인 메모리
>>
>> \- 전체메모리10%(버퍼/캐쉬로 사용될 메모리)
>>
>> = php-fpm 세팅에서 사용할 메모리

### 설치 및 사용
> ```bash
> ~]# cd /opt
> ~]# git clone https://github.com/san0123/php-fpm-calculator
> ~]# cd php-fpm-calculator
> ~]# chmod 700 php-fpm-calculator.sh
> 
> ~]# ./php-fpm-calculator.sh 1
>
> ~]# ./php-fpm-calculator.sh 3
> ```

### 예제 결과 값. (메모리 2GB / 1개 pool)
> ```bash
> ~]# ./phpfpm-calculator.sh 1
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
> 결과 값을 pool 파일에 반영 합니다. `/etc/php-fpm.d/www.conf` 
