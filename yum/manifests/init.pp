class yum (
  $epel = true,
  $epelt = false,
  $rf = true,
  $rft = false,
  $rfx = false,
  $mnx = true
) {
    yumrepo {
        "epel":
            descr          => "Extra Packages for Enterprise Linux 5 - \$basearch",
            mirrorlist     => "http://mirrors.fedoraproject.org/metalink?repo=epel-${lsbmajdistrelease}&arch=\$basearch",
            failovermethod => "priority",
            gpgcheck       => "0",
            enabled        => $yum::epel ? {
              true  => "1",
              false => "0"
            };

        "epel-testing":
            descr          => "Extra Packages for Enterprise Linux 5 - Testing - \$basearch",
            mirrorlist     => "http://mirrors.fedoraproject.org/metalink?repo=testing-epel-${lsbmajdistrelease}&arch=\$basearch",
            failovermethod => "priority",
            gpgcheck       => "0",
            enabled        => $yum::epelt ? {
              true  => "1",
              false => "0"
            };

        "repoforge":
            descr      => "RHEL \$releasever - Repoforge",
            mirrorlist => "http://apt.sw.be/redhat/el${lsbmajdistrelease}/en/mirrors-rpmforge",
            gpgcheck   => "0",
            enabled        => $yum::rf ? {
              true  => "1",
              false => "0"
            };

        "repoforge-extras":
            descr      => "RHEL \$releasever - Repoforge - extras",
            mirrorlist => "http://apt.sw.be/redhat/el${lsbmajdistrelease}/en/mirrors-rpmforge-extras",
            gpgcheck   => "0",
            enabled        => $yum::rfx ? {
              true  => "1",
              false => "0"
            };

        "repoforge-testing":
            descr      => "RHEL \$releasever - Repoforge - testing",
            mirrorlist => "http://apt.sw.be/redhat/el${lsbmajdistrelease}/en/mirrors-rpmforge-testing",
            gpgcheck   => "0",
            enabled        => $yum::rft ? {
              true  => "1",
              false => "0"
            };

        "mnxsolutions":
            descr    => "MNX Solutions Repository",
            baseurl  => "http://yum.mnxsolutions.com/",
            gpgcheck => "0",
            enabled        => $yum::mnx ? {
              true  => "1",
              false => "0"
            };
    }
}
