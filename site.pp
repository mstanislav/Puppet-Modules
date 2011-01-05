Exec { path => "/usr/bin:/usr/sbin/:/bin:/sbin:/usr/local/bin:/usr/local/sbin" }
stage {
    "first": before  => Stage[main];
    "last": require  => Stage[main];
}
