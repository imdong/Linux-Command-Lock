# Linux下命令独占操作锁

增强某些命令，使其同时只能用一个人使用这个命令。
防止同时操作导致冲突。

## 示例配置场景

    一人使用git进行checkout|pull|push|merge相关操作时
    会禁止其他终端使用git进行这些操作。
    防止A刚切到一个分支后，另一个人随后也切换了分支。
    然后A在merge代码时就会合并到错误的分支上。

# 安装方法

示例以git为例子

```
mkdir /usr/local/lock_bin
echo "export PATH=/usr/local/lock_bin:${PATH}" >> /ect/profile
cp command_lock.sh /usr/local/lock_bin/git
sudo chmod +x /usr/local/lock_bin/git
source /ect/profile
```

# 使用方法

    正常使用git即可，在git进行了 checkout|pull|push|merge操作时
    会自动锁定git命令120秒，
    如果执行 git lock 则会手动锁定，且不会超时，
    需要在操作完毕后手动调用 git unlock 进行解锁。
    如果别人操作完之后，亦可调用 git unlock 进行强制解锁。
    强制解锁需要带上 解锁id 操作时会提示解锁id