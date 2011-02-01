class yum {
    yumrepo {
        "epel":
            descr          => "Extra Packages for Enterprise Linux 5 - \$basearch",
            mirrorlist     => "http://mirrors.fedoraproject.org/mirrorlist?repo=epel-5&arch=\$basearch",
            failovermethod => "priority",
            gpgcheck       => "0",
            enabled        => "1";

        "rpmforge":
            descr      => "RHEL \$releasever - RPMforge.net - dag",
            mirrorlist => "http://apt.sw.be/redhat/el5/en/mirrors-rpmforge",
            gpgcheck   => "0",
            enabled    => "1";

        "mnxsolutions":
            descr    => "MNX Solutions Repository",
            baseurl  => "http://yum.mnxsolutions.com/",
            gpgcheck => "0",
            enabled  => "1";
    }
}
