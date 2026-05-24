# EC2 Auto Scaling Group (ASG) Module

## Deskripsi
Module ini digunakan untuk membuat EC2 Auto Scaling Group (ASG) beserta Launch Template di AWS. Module ini mendukung dua jenis auto scaling:
- **CPU-based scaling** (bisa ditambah manual)
- **Queue-based scaling** (berbasis panjang antrian SQS, sesuai arsitektur decoupled)

Module ini cocok digunakan untuk deployment microservices seperti Webinar API Service, Attendance Processor, dan Certificate Generator yang membutuhkan skalabilitas dan decoupling.

---

## Variabel Utama
| Nama                  | Tipe         | Deskripsi                                      |
|-----------------------|--------------|------------------------------------------------|
| `launch_template_name`| string       | Nama prefix Launch Template                    |
| `asg_name`            | string       | Nama Auto Scaling Group                        |
| `ami_id`              | string       | AMI ID untuk instance EC2                      |
| `instance_type`       | string       | Tipe instance EC2                              |
| `key_name`            | string       | Nama SSH key                                   |
| `user_data`           | string       | Script user data (opsional)                    |
| `security_group_ids`  | list(string) | Daftar Security Group ID                       |
| `subnet_ids`          | list(string) | Daftar Subnet ID                               |
| `target_group_arns`   | list(string) | Target group untuk ALB (opsional)              |
| `max_size`            | number       | Maksimum jumlah instance                       |
| `min_size`            | number       | Minimum jumlah instance                        |
| `desired_capacity`    | number       | Jumlah instance awal                           |
| `enable_queue_scaling`| bool         | Aktifkan scaling berbasis SQS queue            |
| `scaling_queue_name`  | string       | Nama SQS queue untuk scaling                   |
| `queue_length_threshold`| number     | Batas panjang queue untuk trigger scaling      |

---

## Output
- `asg_name`: Nama Auto Scaling Group
- `asg_arn`: ARN Auto Scaling Group
- `launch_template_id`: ID Launch Template

---

## Cara Kerja Queue-Based Auto Scaling
Jika `enable_queue_scaling` = `true`, maka module akan membuat:
- **CloudWatch Alarm** pada metric SQS queue (`ApproximateNumberOfMessagesVisible`)
- **Autoscaling Policy** yang akan menambah instance jika panjang queue > `queue_length_threshold`

Cocok untuk Attendance Processor dan Certificate Generator yang workload-nya berbasis event/antrian.

---

## Contoh Pemanggilan di Root
```hcl
module "attendance_processor_asg" {
  source                 = "./modules/ec2_asg"
  asg_name               = "attendance-processor-asg"
  ami_id                 = "ami-xxxxxxxx"
  instance_type          = "t3.micro"
  key_name               = "keypair-name"
  security_group_ids     = ["sg-xxxxxx"]
  subnet_ids             = ["subnet-xxxxxx"]
  enable_queue_scaling   = true
  scaling_queue_name     = "attendance-queue"
  queue_length_threshold = 10
  # variabel lain ...
}
```

---

## Catatan
- Untuk scaling berbasis CPU, tambahkan CloudWatch Alarm dan Autoscaling Policy manual sesuai kebutuhan.
- Module ini bisa dipakai untuk berbagai microservice dengan mengubah parameter saja.
