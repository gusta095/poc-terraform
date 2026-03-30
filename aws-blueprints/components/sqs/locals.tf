locals {
  # Define o nome da fila, adicionando ".fifo" caso seja uma fila FIFO.
  # Usado na interpolação de ARNs nas policies de acesso —
  # uma fila FIFO sem sufixo ".fifo" no ARN gera uma policy inválida na AWS.
  queue_name = var.fifo_queue ? "${var.name}.fifo" : var.name
}
