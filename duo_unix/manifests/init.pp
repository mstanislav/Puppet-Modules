class duo_unix ($duo_ikey = '', $duo_skey = '', $duo_failmode = 'safe') {
    if (($duo_ikey == '') or ($duo_skey == '')) {
        notify { "ikey and skey must both be defined!": }
    } else {
        yumrepo { "mnxsolutions":
            descr    => "MNX Solutions Repository",
            baseurl  => "http://yum.mnxsolutions.com/",
            gpgcheck => "0",
            enabled  => "1";
        }

        package { [ "openssh-server", "duo_unix" ]:
            ensure  => latest,
            require => Yumrepo["mnxsolutions"];
        }

        service { "sshd":
            ensure => running,
            enable => true;
        }

        file { "/etc/duo/login_duo.conf":
            ensure  => present,
            owner   => "sshd",
            group   => "sshd",
            mode    => "0600",
            content => template("duo_unix/login_duo.conf.erb"),
            require => Package["duo_unix"];
        }

        augeas { "SSH Daemon ForceCommand" :
            changes => "set /files/etc/ssh/sshd_config/ForceCommand /usr/sbin/login_duo",
            require => Package["duo_unix"],
            notify  => Service["sshd"];
        }
    }
}
