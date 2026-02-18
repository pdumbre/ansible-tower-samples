all:
  children:
    jump_hosts:
      hosts:
        mgen:
          ansible_host: 10.48.112.47
          ansible_user: root
          ansible_ssh_private_key_file: /runner/.ssh/id_rsa
          ansible_ssh_common_args: -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR
    bmc_servers:
      hosts:
        node_ru2:
          ansible_host: 169.253.1.2
          bmc_ipv6_address: fd8c:215d:178e:c0de:765d:22ff:fee4:2441
          bmc_lla_ip: fe80::765d:22ff:fee4:2441
          ru_number: 2
          node_type: storage
          serial_number: JZ004CR9
          mtm: 7D73CTO1WW
          ibm_serial_number: G2AUTO1-RU2
          ibm_mtm: 9155-C10
          uuid: 5A006E0C441A11EFB336765D22E42443
          location: RU2
          provisioning_mac: 58:a2:e1:54:84:ca
          provisioning_interface: bond1
          baremetal_mac: a0:88:c2:a1:a4:4e
          baremetal_interface: bond0
        node_ru3:
          ansible_host: 169.253.1.3
          bmc_ipv6_address: fd8c:215d:178e:c0de:765d:22ff:fee4:1802
          bmc_lla_ip: fe80::765d:22ff:fee4:1802
          ru_number: 3
          node_type: storage
          serial_number: JZ004CR8
          mtm: 7D73CTO1WW
          ibm_serial_number: G2AUTO1-RU3
          ibm_mtm: 9155-C10
          uuid: AE22AACA443A11EFAA82765D22E41804
          location: RU3
          provisioning_mac: 58:a2:e1:54:88:e6
          provisioning_interface: bond1
          baremetal_mac: a0:88:c2:a1:a8:2a
          baremetal_interface: bond0
        node_ru4:
          ansible_host: 169.253.1.4
          bmc_ipv6_address: fd8c:215d:178e:c0de:765d:22ff:fee4:1825
          bmc_lla_ip: fe80::765d:22ff:fee4:1825
          ru_number: 4
          node_type: storage
          serial_number: JZ004CR6
          mtm: 7D73CTO1WW
          ibm_serial_number: G2AUTO1-RU4
          ibm_mtm: 9155-C10
          uuid: 6940151C441B11EFBE23765D22E41827
          location: RU4
          provisioning_mac: 58:a2:e1:54:93:a6
          provisioning_interface: bond1
          baremetal_mac: a0:88:c2:a1:a5:ea
          baremetal_interface: bond0
        node_ru5:
          ansible_host: 169.253.1.5
          bmc_ipv6_address: fd8c:215d:178e:c0de:765d:22ff:fee4:1ce4
          bmc_lla_ip: fe80::765d:22ff:fee4:1ce4
          ru_number: 5
          node_type: storage
          serial_number: JZ004CRA
          mtm: 7D73CTO1WW
          ibm_serial_number: G2AUTO1-RU5
          ibm_mtm: 9155-C10
          uuid: 59A49098441B11EFA549765D22E41CE6
          location: RU5
          provisioning_mac: 58:a2:e1:54:93:92
          provisioning_interface: bond1
          baremetal_mac: a0:88:c2:a1:a8:6e
          baremetal_interface: bond0
        node_ru6:
          ansible_host: 169.253.1.6
          bmc_ipv6_address: fd8c:215d:178e:c0de:765d:22ff:fee4:326a
          bmc_lla_ip: fe80::765d:22ff:fee4:326a
          ru_number: 6
          node_type: storage
          serial_number: JZ004CR5
          mtm: 7D73CTO1WW
          ibm_serial_number: G2AUTO1-RU6
          ibm_mtm: 9155-C10
          uuid: 774159E644AE11EF9806765D22E4326C
          location: RU6
          provisioning_mac: 58:a2:e1:54:85:8e
          provisioning_interface: bond1
          baremetal_mac: a0:88:c2:a1:a5:f2
          baremetal_interface: bond0
        node_ru7:
          ansible_host: 169.253.1.7
          bmc_ipv6_address: fd8c:215d:178e:c0de:765d:22ff:fee4:18b6
          bmc_lla_ip: fe80::765d:22ff:fee4:18b6
          ru_number: 7
          node_type: storage
          serial_number: JZ004CR7
          mtm: 7D73CTO1WW
          ibm_serial_number: G2AUTO1-RU7
          ibm_mtm: 9155-C10
          uuid: 4F0E67E8441A11EF82EE765D22E418B8
          location: RU7
          provisioning_mac: 58:a2:e1:54:93:9e
          provisioning_interface: bond1
          baremetal_mac: a0:88:c2:a1:a9:ae
          baremetal_interface: bond0
        node_ru23:
          ansible_host: 169.253.1.23
          bmc_ipv6_address: fd8c:215d:178e:c0de:765d:22ff:fedd:5bd9
          bmc_lla_ip: fe80::765d:22ff:fedd:5bd9
          ru_number: 23
          node_type: servicenode
          serial_number: JZ004WY0
          mtm: 7D73CTO1WW
          ibm_serial_number: G2AUTO1-RU23
          ibm_mtm: 9155-C10
          uuid: F75777984B6611EFAED8765D22DD5BDB
          location: RU23
          provisioning_mac: 6c:fe:54:8b:6b:33
          provisioning_interface: bond1
          baremetal_mac: 10:70:fd:d8:6c:7c
          baremetal_interface: bond0
      vars:
        ansible_user: USERID
        ansible_password: '{{ vault_imm_password }}'
        bmc_jump_host: mgen
        bmc_network_interface: eno2
        bmc_ssh_options: -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=30
        powerrp: restore
        failover_mode: shared
    switches:
      hosts:
        hspeed1-f24l026:
          ansible_host: fd8c:215d:178e:c0de:920a:84ff:feaa:7d00
          serial_number: M2NJ29K0004
          ibm_serial_number: G2AUTO1-RU20
          ibm_mtm: 9155-S01
          model: sn3700c
          mac_address: 90:0A:84:AA:7D:00
          location: RU20
          switch_type: tor_network_switch
          manufacturer: Mellanox
          software_version: 5.11.1
        hspeed2-f24l026:
          ansible_host: fd8c:215d:178e:c0de:920a:84ff:feaa:8800
          serial_number: M2NJ29K000F
          ibm_serial_number: G2AUTO1-RU21
          ibm_mtm: 9155-S01
          model: sn3700c
          mac_address: 90:0A:84:AA:88:00
          location: RU21
          switch_type: tor_network_switch
          manufacturer: Mellanox
          software_version: 5.11.1
        mgmt1-f24l026:
          ansible_host: fd8c:215d:178e:c0de:fa8e:a1ff:fe69:e340
          serial_number: 8SSSG7A80795M1ET15T004Z
          ibm_serial_number: G2AUTO1-RU18
          ibm_mtm: 9155-S02
          model: as4610
          mac_address: F8:8E:A1:69:E3:40
          location: RU18
          switch_type: internal_management_switch
          manufacturer: Accton
          software_version: 4.3.4
        mgmt2-f24l026:
          ansible_host: fd8c:215d:178e:c0de:e69d:73ff:fe69:a380
          serial_number: 8SSSG7A80795M1ET2AE003Z
          ibm_serial_number: G2AUTO1-RU19
          ibm_mtm: 9155-S02
          model: as4610
          mac_address: E4:9D:73:69:A3:80
          location: RU19
          switch_type: internal_management_switch
          manufacturer: Accton
          software_version: 4.3.4
      vars:
        ansible_user: cumulus
        ansible_password: '{{ vault_switch_password }}'
        ansible_connection: network_cli
        ansible_network_os: cumulus
    tor_switches:
      hosts:
        hspeed1-f24l026: {}
        hspeed2-f24l026: {}
    mgmt_switches:
      hosts:
        mgmt1-f24l026: {}
        mgmt2-f24l026: {}
    provisioners:
      hosts:
        servicenode:
          ansible_host: fd8c:215d:178e:c0de:6efe:54ff:fe8b:6b33
          location: RU23
          bootstrap_mac: 00:16:3e:54:c0:34
      vars:
        ansible_user: root
        ansible_password: '{{ vault_provisioner_password }}'
    storage_nodes:
      hosts:
        node_ru2: {}
        node_ru3: {}
        node_ru4: {}
        node_ru5: {}
        node_ru6: {}
        node_ru7: {}
    compute_nodes:
      hosts: {}
    service_nodes:
      hosts:
        node_ru23: {}
