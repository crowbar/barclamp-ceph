# Copyright 2011, Dell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
require 'chef'

class CephService < ServiceObject

  def initialize(thelogger)
    @bc_name = "ceph"
    @logger = thelogger
  end

  def create_proposal
    @logger.debug("Ceph create_proposal: entering")
    base = super
    @logger.debug("Ceph create_proposal: exiting")
    base
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("ceph apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    master_mon = role.override_attributes["ceph"]["elements"]["ceph-mon-master"]
    monitors = role.override_attributes["ceph"]["elements"]["ceph-mon"]
    osd_nodes = role.override_attributes["ceph"]["elements"]["ceph-store"]
    @logger.debug("osd_nodes: #{osd_nodes.inspect}")

    if monitors.nil?
      monitors = master_mon
    else
      monitors << master_mon.first
    end
    role.override_attributes["ceph"]["monitors"] = monitors
    role.override_attributes["ceph"]["osds"] = osd_nodes
    role.save

  end

  def validate_proposal proposal
    super

    elements = proposal["deployment"]["ceph"]["elements"]

    # accept proposal with no allocated node -- ie, initial state
    if ((not elements.has_key?("ceph-mon-master") or elements["ceph-mon-master"].length == 0) and
        (not elements.has_key?("ceph-mon") or elements["ceph-mon"].length == 0) and
        (not elements.has_key?("ceph-store") or elements["ceph-store"].length == 0)):
       return
    end

    if proposal["attributes"]["ceph"]["devices"].length < 1
      raise Chef::Exceptions::ValidationFailed.new("Need a list of devices to use on ceph-store nodes in the raw attributes")
    end

    if not elements.has_key?("ceph-mon-master") or elements["ceph-mon-master"].length != 1
      raise Chef::Exceptions::ValidationFailed.new("Need one (and only one) ceph-mon-master node")
    end

    if not elements.has_key?("ceph-mon") or (elements["ceph-mon"].length != 2 and elements["ceph-mon"].length != 4)
      raise Chef::Exceptions::ValidationFailed.new("Need two or four ceph-mon nodes")
    end

    if not elements.has_key?("ceph-store") or elements["ceph-store"].length < 2
      raise Chef::Exceptions::ValidationFailed.new("Need at least two ceph-store nodes")
    end

    if elements["ceph-mon"].include? elements["ceph-mon-master"][0]
      raise Chef::Exceptions::ValidationFailed.new("Node cannot be a member of ceph-mon and ceph-mon-master at the same time")
    end

    elements["ceph-store"].each do |n|
      node = NodeObject.find_node_by_name(n)
      roles = node.roles()
      ["nova-multi-controller", "swift-storage"].each do |role|
        if roles.include?(role)
          raise Chef::Exceptions::ValidationFailed.new("Node #{n} already has the #{role} role; nodes cannot have both ceph-store and #{role} roles")
        end
      end
    end

  end

end
