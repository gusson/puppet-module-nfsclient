# nfsclient
class nfsclient (
  $gss    = false,
  $keytab = undef,
  $mountd_port = undef,
  $statd_port = undef,
  $lockd_tcp_port = undef
  $lockd_udp_port = undef
) {

  # Secure NFS and GSS settings
  case $::osfamily {
    'RedHat': {
      $gss_line     = 'SECURE_NFS'
      $keytab_line  = 'RPCGSSDARGS'
      $service      = 'rpcgssd'
      $nfs_requires = Service['idmapd_service']
      if $::operatingsystemrelease =~ /^7/ {
        if $keytab {
          service { 'nfs-config':
            ensure    => 'running',
            enable    => true,
            subscribe => File_line['GSSD_OPTIONS'],
          }
          file { '/etc/krb5.keytab':
            ensure => 'symlink',
            target => '/etc/opt/quest/vas/host.keytab',
            notify => Service['rpcgssd'],
          }
          if $gss {
            Service['nfs-config'] ~> Service['rpcgssd']
            Service['rpcbind_service'] -> Service['rpcgssd']
          }
        }
      }
    }
    'Suse': {
      $gss_line    = 'NFS_SECURITY_GSS'
      $keytab_line = 'GSSD_OPTIONS'
      $service     = 'nfs'
      if $::operatingsystemrelease =~ /^11/ {
        if $gss {
          file_line { 'NFS_START_SERVICES':
            match  => '^NFS_START_SERVICES=',
            path   => '/etc/sysconfig/nfs',
            line   => 'NFS_START_SERVICES="yes"',
            notify => [ Service[nfs], Service[rpcbind_service], ],
          }
          file_line { 'MODULES_LOADED_ON_BOOT':
            match  => '^MODULES_LOADED_ON_BOOT=',
            path   => '/etc/sysconfig/kernel',
            line   => 'MODULES_LOADED_ON_BOOT="rpcsec_gss_krb5"',
            notify => Exec[gss-module-modprobe],
          }
          exec { 'gss-module-modprobe':
            command     => 'modprobe rpcsec_gss_krb5',
            unless      => 'lsmod | egrep "^rpcsec_gss_krb5"',
            path        => '/sbin:/usr/bin',
            refreshonly => true,
          }
        }
      }
    }
    default: {
      fail("nfsclient module only supports Suse and RedHat. <${::osfamily}> was detected.")
    }
  }

  if $gss {
    include rpcbind
    include nfs::idmap

    file_line { 'NFS_SECURITY_GSS':
      path   => '/etc/sysconfig/nfs',
      line   => "${gss_line}=\"yes\"",
      match  => "^${gss_line}=.*",
      notify => Service[rpcbind_service],
    }

    service { $service:
      ensure    => 'running',
      enable    => true,
      subscribe => [ File_line['NFS_SECURITY_GSS'], File_line['GSSD_OPTIONS'], ],
    }

    if $nfs_requires {
      Service[$service] { require =>  $nfs_requires }
    }
  }
  if $keytab {
    file_line { 'GSSD_OPTIONS':
      path  => '/etc/sysconfig/nfs',
      line  => "${keytab_line}=\"-k ${keytab}\"",
      match => "^${keytab_line}=.*",
    }
    if $gss {
      File_line['GSSD_OPTIONS'] ~> Service['rpcbind_service']
    }
  }

  # NFS ports
  if $mountd_port {
    validate_integer($mountd_port)
    file_line { 'MOUNTD_PORT':
      path  => '/etc/sysconfig/nfs',
      line  => "MOUNTD_PORT=${mountd_port}"
      match => '^#?MOUNTD_PORT=.*'
      notify => Service[rpcbind_service],
    }
  }
  if $statd_port {
    validate_integer($statd_port)
    file_line { 'STATD_PORT':
      path  => '/etc/sysconfig/nfs',
      match => '^#?STATD_PORT=.*'
      line  => "STATD_PORT=${statd_port}"
      notify => Service[rpcbind_service],
    }
  }
  if $lockd_tcp_port {
    validate_integer($lockd_tcp_port)
    file_line { 'LOCKD_TCPPORT':
      path  => '/etc/sysconfig/nfs',
      match => '^#?LOCKD_TCPPORT=.*'
      line  => "LOCKD_TCPPORT=${lockd_tcp_port}"
      notify => Service[rpcbind_service],
    }
  }
  if $lockd_udp_port {
    validate_integer($lockd_udp_port)
    file_line { 'LOCKD_UDPPORT':
      path  => '/etc/sysconfig/nfs',
      match => '^#?LOCKD_UDPPORT=.*'
      line  => "LOCKD_UDPPORT=${lockd_udp_port}"
      notify => Service[rpcbind_service],
    }
  }

}

