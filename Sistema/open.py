#!/usr/bin/env python3
# encoding: utf-8
import socket
import threading
import select
import sys
import time
from os import system

system("clear")

# conexao
IP = '0.0.0.0'
try:
    PORT = int(sys.argv[1])
except:
    PORT = 8080

PASS = ''
BUFLEN = 8196 * 8
TIMEOUT = 60
MSG = 'ALERT'
DEFAULT_HOST = '0.0.0.0:1194'
RESPONSE = f"HTTP/1.1 101 {MSG}\r\n\r\n"

class Server(threading.Thread):
    def __init__(self, host, port):
        super().__init__()
        self.running = False
        self.host = host
        self.port = port
        self.threads = []
        self.threadsLock = threading.Lock()
        self.logLock = threading.Lock()

    def run(self):
        self.soc = socket.socket(socket.AF_INET)
        self.soc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.soc.settimeout(2)
        self.soc.bind((self.host, self.port))
        self.soc.listen(0)
        self.running = True

        try:
            while self.running:
                try:
                    c, addr = self.soc.accept()
                    c.setblocking(1)
                except socket.timeout:
                    continue
                
                conn = ConnectionHandler(c, self, addr)
                conn.start()
                self.addConn(conn)
        finally:
            self.running = False
            self.soc.close()
            
    def printLog(self, log):
        with self.logLock:
            print(log)
    
    def addConn(self, conn):
        with self.threadsLock:
            if self.running:
                self.threads.append(conn)
                    
    def removeConn(self, conn):
        with self.threadsLock:
            self.threads.remove(conn)
                
    def close(self):
        self.running = False
        with self.threadsLock:
            threads = list(self.threads)
            for c in threads:
                c.close()

class ConnectionHandler(threading.Thread):
    def __init__(self, socClient, server, addr):
        super().__init__()
        self.clientClosed = False
        self.targetClosed = True
        self.client = socClient
        self.client_buffer = ''
        self.server = server
        self.log = f'Conexao: {addr}'

    def close(self):
        try:
            if not self.clientClosed:
                self.client.shutdown(socket.SHUT_RDWR)
                self.client.close()
        except:
            pass
        finally:
            self.clientClosed = True
            
        try:
            if not self.targetClosed:
                self.target.shutdown(socket.SHUT_RDWR)
                self.target.close()
        except:
            pass
        finally:
            self.targetClosed = True

    def run(self):
        try:
            self.client_buffer = self.client.recv(BUFLEN)
        
            hostPort = self.findHeader(self.client_buffer, 'X-Real-Host')
            
            if not hostPort:
                hostPort = DEFAULT_HOST

            split = self.findHeader(self.client_buffer, 'X-Split')

            if split:
                self.client.recv(BUFLEN)
            
            if hostPort:
                passwd = self.findHeader(self.client_buffer, 'X-Pass')
                
                if PASS and passwd == PASS:
                    self.method_CONNECT(hostPort)
                elif PASS and passwd != PASS:
                    self.client.send(b'HTTP/1.1 400 WrongPass!\r\n\r\n')
                elif hostPort.startswith(IP):
                    self.method_CONNECT(hostPort)
                else:
                    self.client.send(b'HTTP/1.1 403 Forbidden!\r\n\r\n')
            else:
                print('- No X-Real-Host!')
                self.client.send(b'HTTP/1.1 400 NoXRealHost!\r\n\r\n')

        except Exception as e:
            self.log += f' - error: {e}'
            self.server.printLog(self.log)
        finally:
            self.close()
            self.server.removeConn(self)

    def findHeader(self, head, header):
        aux = head.find(f'{header}: ')
    
        if aux == -1:
            return ''

        aux = head.find(':', aux)
        head = head[aux+2:]
        aux = head.find('\r\n')

        if aux == -1:
            return ''

        return head[:aux]

    def connect_target(self, host):
        i = host.find(':')
        if i != -1:
            port = int(host[i+1:])
            host = host[:i]
        else:
            port = 443 if self.method == 'CONNECT' else 22

        soc_family, soc_type, proto, _, address = socket.getaddrinfo(host, port)[0]

        self.target = socket.socket(soc_family, soc_type, proto)
        self.targetClosed = False
        self.target.connect(address)

    def method_CONNECT(self, path):
        self.log += f' - CONNECT {path}'
        self.connect_target(path)
        self.client.sendall(RESPONSE.encode('utf-8'))
        self.client_buffer = ''
        self.server.printLog(self.log)
        self.doCONNECT()
                    
    def doCONNECT(self):
        socs = [self.client, self.target]
        count = 0
        error = False
        while True:
            count += 1
            recv, _, err = select.select(socs, [], socs, 3)
            if err:
                error = True
            if recv:
                for in_ in recv:
                    try:
                        data = in_.recv(BUFLEN)
                        if data:
                            if in_ is self.target:
                                self.client.send(data)
                            else:
                                while data:
                                    byte = self.target.send(data)
                                    data = data[byte:]
                            count = 0
                        else:
                            break
                    except:
                        error = True
                        break
            if count == TIMEOUT:
                error = True

            if error:
                break

def main(host=IP, port=PORT):
    print("\033[0;34m━"*8+"\033[1;32m PROXY SOCKS\033[0;34m━"*8+"\n")
    print(f"\033[1;33mIP:\033[1;32m {IP}")
    print(f"\033[1;33mPORTA:\033[1;32m {PORT}\n")
    print("\033[0;34m━"*10+"\033[1;32m SSHPLUS\033[0;34m━\033[1;37m"*11+"\n")
    server = Server(IP, PORT)
    server.start()
    while True:
        try:
            time.sleep(2)
        except KeyboardInterrupt:
            print('\nParando...')
            server.close()
            break

if __name__ == '__main__':
    main()
