class foreman {
    exec { "rake db:migrate":
        cwd         => "/usr/share/foreman",
        environment => "RAILS_ENV=production",
        subscribe   => File["/etc/foreman/database.yml"],
        refreshonly => true;
    }

    package { "foreman":
        ensure  => present,
        require => [ Yumrepo["mnxsolutions"], Package["httpd"], Package["rubygem-passenger"], Package["mysql-server"] ];
    }

    service { "foreman":
        ensure    => stopped,
        enable    => false,
        hasstatus => true,
        require => Package["foreman"];
    }

    file {
        "/etc/httpd/conf.d/foreman.conf":
            ensure  => present,
            owner   => "root",
            group   => "root",
            mode    => "0644",
            content => template("foreman/foreman-vhost.conf.erb"),
            require => Package["foreman"],
            notify  => Service["httpd"];
        
        "/etc/foreman/email.yaml":
            ensure  => present,
            owner   => "root",
            group   => "root",
            mode    => "0644",
            content => template("foreman/email.yaml.erb"),
            require => Package["foreman"];
        
        "/etc/foreman/database.yml":
            ensure  => present,
            owner   => "root",
            group   => "root",
            mode    => "0644",
            source  => "puppet:///modules/foreman/database.yml",
            require => Package["foreman"];
        
        "/etc/foreman/settings.yaml":
            ensure  => present,
            owner   => "root",
            group   => "root",
            mode    => "0644",
            source  => "puppet:///modules/foreman/settings.yaml",
            require => Package["foreman"];

        "/usr/lib/ruby/site_ruby/1.8/puppet/reports/foreman.rb":
            ensure  => present,
            owner   => "root",
            group   => "root",
            mode    => "0644",
            source  => "puppet:///modules/foreman/foreman.rb",
            require => Package["foreman"];
    }

    cron { "Foreman Updates":
        ensure      => present,
        command     => "cd /usr/share/foreman && rake puppet:migrate:populate_hosts > /dev/null 2>&1",
        environment => "RAILS_ENV=production",
        user        => "root",
        minute      => "*/15";
    }
}
