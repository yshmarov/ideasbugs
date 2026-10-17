# frozen_string_literal: true

ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :ideasbugs_feedbacks, force: true do |t|
    t.string :kind, null: false, default: 'other'
    t.string :section
    t.text :message, null: false
    t.string :status, null: false, default: 'open'
    t.string :page_url
    t.string :user_agent
    t.string :author_id
    t.string :author_label
    t.string :tenant
    t.timestamps
  end
  add_index :ideasbugs_feedbacks, :status
  add_index :ideasbugs_feedbacks, :kind
  add_index :ideasbugs_feedbacks, %i[tenant status]

  # Active Storage tables, so screenshot attachments work in tests.
  create_table :active_storage_blobs, force: true do |t|
    t.string :key, null: false
    t.string :filename, null: false
    t.string :content_type
    t.text :metadata
    t.string :service_name, null: false
    t.bigint :byte_size, null: false
    t.string :checksum
    t.datetime :created_at, null: false
    t.index [:key], unique: true
  end

  create_table :active_storage_attachments, force: true do |t|
    t.string :name, null: false
    t.string :record_type, null: false
    t.bigint :record_id, null: false
    t.bigint :blob_id, null: false
    t.datetime :created_at, null: false
    t.index [:blob_id]
    t.index %i[record_type record_id name blob_id],
            unique: true, name: 'index_active_storage_attachments_uniqueness'
  end

  create_table :active_storage_variant_records, force: true do |t|
    t.bigint :blob_id, null: false
    t.string :variation_digest, null: false
    t.index %i[blob_id variation_digest],
            unique: true, name: 'index_active_storage_variant_records_uniqueness'
  end
end
