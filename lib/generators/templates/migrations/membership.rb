class TreelifyCreateMemberships < ActiveRecord::Migration
  def change
    create_table :treelify_members do |t|
      t.belongs_to :user
      t.belongs_to :hierarchy
      t.timestamps null: false
    end

    create_table :treelify_roles do |t|
      t.string :name, null: false
      t.integer :level, default: 0, null: false
      t.boolean :inherited, default: true, null: false
      t.timestamps null: false
    end

    add_index :treelify_roles, :name, unique: true

    create_table :treelify_members_roles do |t|
      t.belongs_to :role
      t.belongs_to :member
      t.timestamps null: false
    end

    add_index :treelify_members_roles, [:role_id, :member_id], unique: true
  end
end
