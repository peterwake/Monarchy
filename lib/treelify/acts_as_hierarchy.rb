# frozen_string_literal: true
module Treelify
  module ActsAsHierarchy
    extend ActiveSupport::Concern

    module ClassMethods
      def acts_as_hierarchy
        has_closure_tree dependent: :destroy

        has_many :members, class_name: 'Treelify::Member'
        belongs_to :resource, polymorphic: true, dependent: :destroy

        validates :resource, presence: true

        include Treelify::ActsAsHierarchy::InstanceMethods
      end
    end

    module InstanceMethods
      def memberless_ancestors_for(user)
        ancestors.joins('LEFT JOIN treelify_members on treelify_hierarchies.id = treelify_members.hierarchy_id')
                 .where("treelify_members.user_id != #{user.id} OR treelify_members.id IS NULL")
      end
    end
  end
end

ActiveRecord::Base.send :include, Treelify::ActsAsHierarchy
