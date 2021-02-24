var obj = JSON.parse($response.body);

if ($request.url.indexOf("/user/personal") != -1){

    obj.data.vip = 1;
    obj.data.vip_time = "2099-09-09 09:09:09";
    obj.data.nickname = "ios黑科技";
    obj.data.vip_ymd = "2099-09-09";
    obj.data.huancun_count = 5201314;
    
}
if ($request.url.indexOf("/community/edit") != -1){

    obj.code = 200;
    
    
}


$done({body: JSON.stringify(obj)});
