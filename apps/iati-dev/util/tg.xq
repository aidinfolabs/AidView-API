let $g-b-data := <items>
    <item>
        <key1>1</key1>
        <key2>a</key2>
    </item>
    <item>
        <key1>1</key1>
        <key2>b</key2>
    </item>
    <item>
        <key1>0</key1>
        <key2>c</key2>
    </item>
    <item>
        <key1>0</key1>
        <key2>d</key2>
    </item>
</items>

(: grouping query :)
return
for $item in $g-b-data//item
group $item as $partition by $item/key1 as $key1
return
<group>
  {$key1,$partition}
</group>


