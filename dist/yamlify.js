function genSpaces(e){for(var n="",r=e;r--;)n+=" ";return n}function indentSpaces(e){return e>100?genSpaces(e):spaces.substr(0,e)}function traverse(e,n,r){if(e===nil);else if(null===e)$str+="null";else{var t,s,a=e.constructor;switch(a!==Array&&a!==Object||r!==Array&&r!==Object||(n+=$indent),a){case String:$str+=complexStrReg.test(e)?"|-"+$indent+"\n"+e.replace(beginReg,indentSpaces($indent+n)):"'"+e+"'";break;case Number:$str+=e;break;case Array:for(s=e.length,t=0;t<s;t++)$str+="\n"+indentSpaces(n)+"- ",traverse(e[t],n,a);break;case Boolean:$str+=e;break;default:for(t in e)$str+="\n"+indentSpaces(n)+t+": ",traverse(e[t],n,a)}}}var nil,complexStrReg=/[\n']/,beginReg=/^/gm,spaces=genSpaces(100);module.exports=function(e,n){return e===nil?nil:($str="",$indent=n||4,traverse(e,0),$str)};var $str,$indent;