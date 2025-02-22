module VCloudSdk
  module Xml

    class Vm < Wrapper
      def attach_disk_link
        get_nodes("Link", {"rel" => "disk:attach",
          "type" => MEDIA_TYPE[:DISK_ATTACH_DETACH_PARAMS]}, true).first
      end

      def description
        nodes = get_nodes("Description")
        return nodes unless nodes
        node = nodes.first
        return node unless node
        node.content
      end

      def description=(value)
        nodes = get_nodes("Description")
        return unless nodes
        node = nodes.first
        return unless node
        node.content = value
      end

      def detach_disk_link
        get_nodes("Link", {"rel" => "disk:detach",
          "type" => MEDIA_TYPE[:DISK_ATTACH_DETACH_PARAMS]}, true).first
      end

      def power_on_link
        get_nodes("Link", {"rel" => "power:powerOn"}, true).first
      end

      def power_off_link
        get_nodes("Link", {"rel" => "power:powerOff"}, true).first
      end

      def reboot_link
        get_nodes("Link", {"rel" => "power:reboot"}, true).first
      end

      def undeploy_link
        get_nodes("Link", {"rel" => "undeploy"}, true).first
      end

      def remove_link(force = false)
        get_nodes("Link", {"rel" => "remove"}, true).first
      end

      def discard_state
        get_nodes("Link", {"rel" => "discardState"}, true).first
      end

      def edit_link
        get_nodes("Link", {"rel" => "edit"}, true).first
      end

      def reconfigure_link
        get_nodes("Link", {"rel" => "reconfigureVm"}, true).first
      end

      def insert_media_link
        get_nodes("Link", {"rel" => "media:insertMedia"}, true).first
      end

      def eject_media_link
        get_nodes("Link", {"rel" => "media:ejectMedia"}, true).first
      end

      def metadata_link
        get_nodes("Link", {"type" => MEDIA_TYPE[:METADATA]}, true).first
      end

      def container_vapp_link
        get_nodes("Link", {"type" => MEDIA_TYPE[:VAPP]}, true).first
      end

      def prerunning_tasks
        tasks.find_all { |t| PRE_RUNNING_TASK_STATUSES.include?(t.status) }
      end

      def running_tasks
        get_nodes("Task", {"status" => "running"})
      end

      def tasks
        get_nodes("Task")
      end

      def name
         @root["name"]
      end

      def name=(value)
         @root["name"]= value
      end

      def agent_id
         @root["agent_id"]
      end

      def agent_id=(value)
         @root["agent_id"]= value
      end

      def hardware_section
        get_nodes("VirtualHardwareSection", nil, false,
          "http://schemas.dmtf.org/ovf/envelope/1").first
      end

      def network_connection_section
        get_nodes("NetworkConnectionSection",
          {"type" => MEDIA_TYPE[:NETWORK_CONNECTION_SECTION]}).first
      end

      # hardware modification methods
      def add_hard_disk(size_mb)
        section = hardware_section
        scsi_controller = section.scsi_controller
        unless scsi_controller
          raise ObjectNotFoundError, "No SCSI controller found for VM #{name}"
        end
        # Create a RASD item
        new_disk = WrapperFactory.create_instance("Item", nil,
          hardware_section.doc_namespaces)
        section.add_item(new_disk)
        # The order matters!
        previous_disks_list = Array.new(hardware_section.hard_disks)
        index = previous_disks_list.length 

        address_on_parent = RASD_TYPES[:ADDRESS_ON_PARENT]
        new_disk.add_rasd(address_on_parent)
        new_disk.set_rasd(address_on_parent, index)

        description = RASD_TYPES[:DESCRIPTION]
        new_disk.add_rasd(description)
        new_disk.set_rasd(description, "Hard Disk")

        element_name = RASD_TYPES[:ELEMENT_NAME]
        new_disk.add_rasd(element_name)
        new_disk.set_rasd(element_name, "Hard Disk #{index}")

        new_disk.add_rasd(RASD_TYPES[:HOST_RESOURCE])
        host_resource = new_disk.get_rasd(RASD_TYPES[:HOST_RESOURCE])
        host_resource[new_disk.create_qualified_name(
          "capacity", VCLOUD_NAMESPACE)] = size_mb.to_s
        host_resource[new_disk.create_qualified_name(
          "busSubType", VCLOUD_NAMESPACE)] = scsi_controller.get_rasd_content(
            RASD_TYPES[:RESOURCE_SUB_TYPE])
        host_resource[new_disk.create_qualified_name(
          "busType", VCLOUD_NAMESPACE)] = HARDWARE_TYPE[:SCSI_CONTROLLER]

        instance_id_type = RASD_TYPES[:INSTANCE_ID]
        new_disk.add_rasd(instance_id_type)
        new_disk.set_rasd(instance_id_type, section.highest_instance_id + 1)
        
        pt = RASD_TYPES[:PARENT]
        new_disk.add_rasd(pt)
        new_disk.set_rasd(pt, scsi_controller.get_rasd_content(RASD_TYPES[:INSTANCE_ID]))

        rt = RASD_TYPES[:RESOURCE_TYPE]
        new_disk.add_rasd(rt)
        new_disk.set_rasd(rt, HARDWARE_TYPE[:HARD_DISK])
      end

      def find_attached_disk(disk)
        href = disk.is_a?(String) ? disk : disk.href
        hardware_section.hard_disks.find do |d|
          hard_disk_href = d.disk_href
          next if hard_disk_href.nil?
          hard_disk_href == href
        end
      end

      def change_cpu_count(quantity)
        item = hardware_section.cpu
        item.set_rasd("VirtualQuantity", quantity)
      end

      def change_memory(mb)
        item = hardware_section.memory
        item.set_rasd("VirtualQuantity", mb)
      end

      def add_nic(nic_index, network_name, addressing_mode, ip = nil)
        section = hardware_section
        is_primary = hardware_section.nics.length == 0
        new_nic = Xml::NicItemWrapper.new(Xml::WrapperFactory.create_instance(
          "Item", nil, hardware_section.doc_namespaces))
        section.add_item(new_nic)
        new_nic.nic_index = nic_index
        new_nic.network = network_name
        new_nic.set_ip_addressing_mode(addressing_mode, ip)
        new_nic.is_primary = is_primary
        new_nic.description = "NIC"
        new_nic.element_name = "NIC #{nic_index}"
      end

      # NIC modification methods

      def connect_nic(nic_index, network_name, addressing_mode,
          ip_address = nil)
        section = network_connection_section
        new_connection = WrapperFactory.create_instance("NetworkConnection",
          nil, network_connection_section.doc_namespaces)
        section.add_item(new_connection)
        new_connection.network_connection_index = nic_index
        new_connection.network = network_name
        new_connection.ip_address_allocation_mode = addressing_mode
        new_connection.ip_address = ip_address if ip_address
        new_connection.is_connected = true
      end

      # Deletes NIC from VM.  Accepts variable number of arguments for NICs.
      # To delete all NICs from VM use the splat operator
      # ex: delete_nic(vm, *vm.hardware_section.nics)
      def delete_nic(*nics)
        # Trying to remove a NIC without removing the network connection
        # first will cause an error.  Removing the network connection of a NIC
        # in the NetworkConnectionSection will automatically delete the NIC.
        net_conn_section = network_connection_section
        vhw_section = hardware_section
        nics.each do |nic|
          nic_index = nic.nic_index
          net_conn_section.remove_network_connection(nic_index)
          vhw_section.remove_nic(nic_index)
        end
      end

      def set_nic_is_connected(nic_index, is_connected)
        net_conn_section = network_connection_section
        connection = net_conn_section.network_connection(nic_index)
        unless connection
          raise ObjectNotFoundError,
            "NIC #{nic_index} cannot be found on VM #{name}."
        end
        connection.is_connected = is_connected
      end

      def set_primary_nic(nic_index)
        net_conn_section = network_connection_section
        net_conn_section.primary_network_connection_index = nic_index
      end
    end

  end
end
