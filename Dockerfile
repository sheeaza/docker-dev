FROM alpine:latest as build

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories
RUN apk add -U --no-cache build-base ncurses-dev py3-pip python3-dev git bash cmake

WORKDIR /root/tmp/
# gtags
RUN wget https://www.tamacom.com/global/global-6.6.5.tar.gz && tar xvf global-6.6.5.tar.gz && \
    cd global-6.6.5 && ./configure && make -j8 && make install-exec DESTDIR=/root/tmp/global/install

COPY pyreq.txt /root/tmp/
RUN  pip install -r pyreq.txt --prefix=/root/tmp/pipinstall

#Leaderf plugin that need build
RUN git clone https://github.com/Yggdroot/LeaderF.git && cd LeaderF && ./install.sh

#################################### deploy ##############################
# ssh rg git nvim fish fzf tmux gtags
FROM alpine:latest as deploy

COPY --from=build /root/tmp/global/install/usr/local/bin/ /usr/local/bin/
COPY --from=build /root/tmp/pipinstall /usr/

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories
RUN apk add -U --no-cache \
    neovim git \
    fish tmux openssh-client bash \
    tree curl less ripgrep perl py3-pip tar npm findutils tig ctags \
    clang-extra-tools

ENV LANG=C.UTF-8 LANGUAGE=C.UTF-8 LC_ALL=C.UTF-8
# TERM
ENV TERM=xterm-256color

#tmux config
WORKDIR /root/
RUN git clone https://github.com/gpakosz/.tmux.git && ln -s -f .tmux/.tmux.conf && cp .tmux/.tmux.conf.local .
COPY tmux.conf.local /root/.tmux.conf.local

#nvim
RUN npm install -g neovim
RUN sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
WORKDIR /root/.config/nvim/
RUN git clone https://github.com/sheeaza/nvim.config.git  .
RUN nvim --headless +PlugInstall +qall && nvim --headless '+CocInstall -sync coc-clangd' +qall
COPY --from=build /root/tmp/LeaderF/autoload/leaderf/python/ /root/.local/share/nvim/plugged/LeaderF/autoload/leaderf/python/
ENV VIRTUAL=nvim
ENV EDITOR=nvim

# fish
RUN curl -L https://get.oh-my.fish > install && fish install --noninteractive --yes
RUN fish -c 'omf install clearance' && fish -c 'set -Ux EDITOR nvim' && fish -c 'set -Ux VISUAL nvim' && \
    fish -c 'alias -s l="ls --group-directories-first"' && \
    fish -c 'alias -s la="l -a"' && fish -c 'alias -s ll="l -lh"' && fish -c 'alias -s lla="ll -a"' && \
    fish -c 'alias -s git-root="cd (git rev-parse --show-toplevel)"' && \
    fish -c 'set -U fish_user_paths /root/bin $fish_user_paths' && \
    mkdir -p /root/.local/share/fish/generated_completions #see https://github.com/fish-shell/fish-shell/issues/7183
COPY fish_prompt.fish /root/.local/share/omf/themes/clearance/fish_prompt.fish

# fzf
RUN git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install --all

# switch shell to fish
RUN sed -i 's/\/root:\/bin\/ash/\/root:\/usr\/bin\/fish/g' /etc/passwd

WORKDIR /root/
ENTRYPOINT ["/usr/bin/fish"]
