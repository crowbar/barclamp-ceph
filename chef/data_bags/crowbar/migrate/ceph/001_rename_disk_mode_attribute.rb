def upgrade ta, td, a, d
  a['ceph']['disk_mode'] = a['ceph']['disk-mode']
  a['ceph'].delete('disk-mode')
  return a, d
end

def downgrade ta, td, a, d
  a['ceph']['disk-mode'] = a['ceph']['disk_mode']
  a['ceph'].delete('disk_mode')
  return a, d
end
