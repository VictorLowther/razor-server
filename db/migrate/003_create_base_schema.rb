Sequel.migration do
  up do
    extension(:constraint_validations)

    create_table :images do
      primary_key :id
      String      :name, :null => false, :unique => true
      String      :type, :null => false
      String      :path, :null => false
      String      :status
      String      :os_name
      String      :os_version

      validate do
        includes %w[mk os esxi], :type, :name => 'valid_image_types'
      end
    end

    create_table :policies do
      primary_key :id
      String      :name, :null => false, :unique => true
      foreign_key :image_id, :images, :null => false
      # FIXME: this needs to become an FK as soon as we have an installers table
      String      :installer_name, :null => false
      String      :hostname_pattern, :null => false
      TrueClass   :enabled
      Integer     :max_count
      Integer     :sort_order
    end

    create_table :tags do
      primary_key :id
      String      :name, :null => false, :unique => true
      String      :rule
    end

    create_table :nodes do
      primary_key :id
      # FIXME: store hw_id as an array of MACs rather than a concatenation
      # of MAC's
      String      :hw_id, :null => false
      index  Sequel.function(:lower, :hw_id), :unique => true,
                                              :name => 'nodes_hw_id_index'

      foreign_key :policy_id, :policies
      # FIXME: the log should go into its own table, with a timestamp
      # generated by the DB
      String      :log
      String      :facts

      # FIXME: Determine if we even need to store this (it only seems to be
      # used to log into the node via ssh to setup the broker; and we
      # should do that by pulling a broker install script from the node)
      String      :ip_address
      Integer     :boot_count, :default => 0
    end

    create_join_table( :tag_id => :tags, :policy_id => :policies)
  end

  down do
    extension(:constraint_validations)

    drop_table :policies_tags
    drop_table :tags
    drop_table :policies

    drop_table :models

    drop_constraint_validations_for :table => :images
    drop_table :images

    drop_table :nodes
  end
end
